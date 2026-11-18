//
//  PiPManager.swift
//  VidyoConnector
//
//  System Picture-in-Picture engine for the VidyoConnector (VCConnector) sample.
//
//  The Vidyo SDK has no built-in PiP. This file:
//  - Pulls raw remote frames via VCRemoteCamera / VCRemoteWindowShare registerFrameEventListener
//  - Converts VCVideoFrame (I420) → NV12 CMSampleBuffer
//  - Feeds AVSampleBufferDisplayLayer inside AVPictureInPictureVideoCallViewController
//  - Keeps ConnectorManager.isSystemPiPActive so the connector stays in foreground while PiP shows
//
//  Call state (cameras, shares, pin, loudest, mic) comes from PiPCallDataSource — see
//  PiPCallDataSource.swift. Do not wire NeoIOS types into this file.
//
//  Requirements:
//  - iOS 15+, Background Modes: Audio + Picture in Picture (and usually voip)
//  - Optional: AVCaptureSession+Multitasking.m for local camera in background (iOS 16+)
//
//  Sample usage (auto-start; no toolbar button):
//  1. configure(sourceView:dataSource:) once the conference render view is in a window
//  2. requestBackgroundStart(...) from UIScene.willDeactivateNotification
//  3. stop(force:) + resetBackgroundCycle() when returning to foreground
//  4. tearDown(invalidate: true) when the call ends
//
//  Focus priority: remote share > pinned > loudest > first remote camera
//  (initials placeholder when the focused participant has no video)
//

import UIKit
import AVFoundation
import AVKit
import CoreMedia
import CoreVideo
import os
import VidyoClientIOS

// MARK: - Logging helpers
// os.Logger string interpolations run in an autoclosure; build the String first so callers
// do not need explicit `self.` for every property.

fileprivate func pipLogInfo(_ message: String) {
    Logger().info("\(message)")
}

fileprivate func pipLogWarning(_ message: String) {
    Logger().warning("\(message)")
}

fileprivate func pipLogError(_ message: String) {
    Logger().error("\(message)")
}

private extension String {
    /// First letter of each whitespace-separated word — used for PiP initials disks.
    func getOnlyFirstLetters() -> String? {
        let parts = split(whereSeparator: { $0.isWhitespace })
        let letters = parts.compactMap { $0.first.map(String.init) }
        guard !letters.isEmpty else { return nil }
        return letters.joined()
    }
}

// MARK: - Public API

/// Host callbacks for PiP active/canStart changes and start failures (main thread).
@available(iOS 15.0, *)
protocol PiPManagerDelegate: AnyObject {
    func pipManager(_ manager: PiPManager, didChangeActive isActive: Bool, canStart: Bool)
    func pipManager(_ manager: PiPManager, didFailWith error: Error)
}

/// One instance per call screen. Owns AVKit PiP and the remote-frame pipeline.
@available(iOS 15.0, *)
final class PiPManager {

    /// Device / OS supports video-call PiP.
    static var isSupported: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    weak var delegate: PiPManagerDelegate?

    /// PiP window is currently showing (optimistic: true from willStart).
    var isActive: Bool { coordinator?.isActive ?? false }
    /// AVKit reports the system PiP window is actually active (not just willStart).
    var isPictureInPictureActive: Bool { coordinator?.isPictureInPictureActive ?? false }
    /// AVKit reports PiP can be started from the current source view.
    var canStart: Bool { coordinator?.canStartPictureInPicture ?? false }

    private var coordinator: SystemPiPCoordinator?
    /// Debounce timestamp for background auto-start.
    private var lastBackgroundTriggerTs: CFTimeInterval = 0
    /// Only one auto-start attempt per background cycle (re-armed by `resetBackgroundCycle()`).
    private var didAttemptInCurrentBackgroundCycle = false
    private var didReceiveSceneWillDeactivate = false

    /// Bind the SDK composite render view and call-state data source. Safe to call repeatedly.
    /// - Parameters:
    ///   - sourceView: Must be the view passed to `assignView(toCompositeRenderer:)` and in a window.
    ///   - dataSource: Cameras / shares / pin / loudest / mic (see `PiPCallDataSource`).
    func configure(sourceView: UIView, dataSource: PiPCallDataSource?) {
        if let coordinator = coordinator {
            coordinator.updateSourceView(sourceView)
        } else {
            let coordinator = SystemPiPCoordinator(sourceView: sourceView)
            coordinator.delegate = self
            // Expand control inside the PiP window — same path as returning to the app.
            coordinator.onExpandRequested = { [weak self] in
                DispatchQueue.main.async {
                    self?.coordinator?.stopPictureInPictureForForegroundReturn()
                }
            }
            self.coordinator = coordinator
        }
        if let dataSource = dataSource {
            coordinator?.configurePiPFocusDependencies(dataSource: dataSource)
        }
    }

    /// Call when the composite render view is recreated (layout refresh / rotation).
    /// Pass `forceRebuild: true` only when returning from an active PiP session and the
    /// AVKit controller must be replaced; never rebuild during a background start.
    func updateSourceView(_ sourceView: UIView, forceRebuild: Bool = false) {
        coordinator?.updateSourceView(sourceView, forceRebuild: forceRebuild)
    }

    /// Manual start/stop (optional toolbar button). This sample uses auto-start instead.
    func toggle() {
        coordinator?.setPiPStartBlocked(false)
        coordinator?.togglePictureInPicture()
    }

    /// Stop PiP (e.g. app returned to foreground). Does not release the controller unless you tear down.
    func stop(force: Bool) {
        coordinator?.stopPictureInPicture(force: force)
    }

    /// End-of-call cleanup. Prefer `invalidate: true` so no PiP bubble survives hang-up.
    /// Blocks late starts, stops PiP, optionally releases AVKit, clears `isSystemPiPActive`.
    func tearDown(invalidate: Bool) {
        coordinator?.setPiPStartBlocked(true)
        coordinator?.stopPictureInPicture(force: true)
        coordinator?.stopPictureInPictureForForegroundReturn()
        if invalidate {
            coordinator?.invalidateForCallTeardown()
            coordinator = nil
        }
        ConnectorManager.shared.setSystemPiPActive(false)
    }

    /// Call when returning to foreground so the next background can auto-start PiP again.
    func resetBackgroundCycle() {
        didAttemptInCurrentBackgroundCycle = false
        didReceiveSceneWillDeactivate = false
    }

    /// Deferred cancelled-Home cleanup only: clear mid-start / optimistic flags without
    /// calling `stopPictureInPicture()` (that races AVKit and flashes the first swipe off).
    /// No-op while AVKit reports the PiP window active — caller should `stop(force:)` instead.
    /// Do not call from SceneDidBecomeActive bounce; that races willStart.
    func clearOptimisticBackgroundStartIfNeeded() {
        guard let coordinator = coordinator else {
            ConnectorManager.shared.setSystemPiPActive(false)
            resetBackgroundCycle()
            return
        }
        if coordinator.isPictureInPictureActive {
            // Real PiP over foreground — leave it; delayed cleanup or user return will stop.
            return
        }
        coordinator.clearInFlightStartWithoutStoppingController()
        ConnectorManager.shared.setSystemPiPActive(false)
        resetBackgroundCycle()
    }

    /// Call from `UIScene.willDeactivateNotification` before `requestBackgroundStart`.
    func noteSceneWillDeactivate() {
        didReceiveSceneWillDeactivate = true
    }

    /// Auto-start PiP while the scene is still `.foregroundActive` (required by AVKit).
    /// - Parameters:
    ///   - reason: e.g. `"UISceneWillDeactivate"` or `"AppDelegateEarlySignal"`.
    ///   - sceneState: Current scene activation state (must be `.foregroundActive` to start).
    ///   - isCallActive: Host says the conference is connected and not tearing down.
    func requestBackgroundStart(reason: String, sceneState: UIScene.ActivationState?, isCallActive: Bool) {
        guard PiPManager.isSupported else { return }
        guard isCallActive else {
            pipLogInfo("System PiP background trigger ignored: call not active (\(reason))")
            return
        }
        guard let coordinator = coordinator, !coordinator.isActive else { return }

        let sceneStateRaw = sceneState?.rawValue ?? -1
        if reason == "AppDelegateEarlySignal" && !didReceiveSceneWillDeactivate {
            pipLogInfo("System PiP background trigger ignored: early signal without scene deactivation")
            return
        }
        if sceneState != .foregroundActive {
            pipLogInfo("System PiP background trigger ignored: \(reason) but scene not active, sceneState=\(sceneStateRaw)")
            return
        }
        guard !didAttemptInCurrentBackgroundCycle else {
            pipLogInfo("System PiP background trigger ignored: already attempted in this cycle (\(reason))")
            return
        }
        let now = CACurrentMediaTime()
        if now - lastBackgroundTriggerTs < 0.25 {
            pipLogInfo("System PiP background trigger ignored (debounced): \(reason)")
            return
        }
        lastBackgroundTriggerTs = now
        didAttemptInCurrentBackgroundCycle = true
        didReceiveSceneWillDeactivate = false

        pipLogInfo("System PiP background trigger: \(reason), appState=\(UIApplication.shared.applicationState.rawValue), sceneState=\(sceneStateRaw)")
        // Keep renderer alive during transition; reset in the failure callback if startup fails.
        ConnectorManager.shared.setSystemPiPActive(true)
        coordinator.setPiPStartBlocked(false)
        coordinator.startPictureInPictureForBackgroundTransition()
    }
}

@available(iOS 15.0, *)
extension PiPManager: SystemPiPCoordinatorDelegate {
    fileprivate func systemPiPCoordinator(_ coordinator: SystemPiPCoordinator, didUpdateState active: Bool, canStart: Bool) {
        ConnectorManager.shared.setSystemPiPActive(active)
        delegate?.pipManager(self, didChangeActive: active, canStart: canStart)
    }

    fileprivate func systemPiPCoordinator(_ coordinator: SystemPiPCoordinator, didFailWith error: Error) {
        let nsError = error as NSError
        pipLogError("System PiP failed: \(error.localizedDescription), domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)")
        ConnectorManager.shared.setSystemPiPActive(false)
        resetBackgroundCycle()
        delegate?.pipManager(self, didFailWith: error)
    }
}

// MARK: - Internals
// Everything below is private to this file. Host apps should only use PiPManager + PiPCallDataSource.

// MARK: Focus tracking
// Resolves which remote stream (or initials placeholder) PiP should show.
// Priority: remote share → pinned → loudest → first remote camera.

@available(iOS 15.0, *)
fileprivate enum PiPFocusTarget {
    case none
    case camera(VCRemoteCamera)
    case share(VCRemoteWindowShare)
    /// Focused participant has no live camera row — SDK removes the object when video is off.
    case remoteVideoUnavailable(userId: String)
}

/// Observes `PiPCallDataSource` and emits the current focus target for frame binding.
@available(iOS 15.0, *)
fileprivate final class PiPFocusTracker {

    private weak var dataSource: PiPCallDataSource?
    private var focusObserverToken: AnyObject?

    var onFocusTargetChanged: ((PiPFocusTarget, Bool) -> Void)?

    private var isStarted = false
    private var debounceWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 0.15
    private var lastEmitted: PiPFocusTarget = .none
    private var stickyCameraOffUserId: String?
    private var lastCameraUserIds: [ObjectIdentifier: String] = [:]

    var currentFocusTarget: PiPFocusTarget { lastEmitted }

    init(dataSource: PiPCallDataSource) {
        self.dataSource = dataSource
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        registerObservers()
        emitIfChanged(force: true)
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        unregisterObservers()
        stickyCameraOffUserId = nil
        lastCameraUserIds.removeAll()
        lastEmitted = .none
    }

    func recomputeNow() {
        DispatchQueue.main.async { [weak self] in
            self?.emitIfChanged(force: true)
        }
    }

    private func activeRemoteShareTarget() -> PiPFocusTarget? {
        guard let dataSource = dataSource else { return nil }
        let ownId = dataSource.localUserId
        let shares = dataSource.remoteShareSnapshot()
        let remoteShares = shares.filter { ($0.participant.getId() ?? "") != ownId }
        guard let shareObj = remoteShares.first ?? shares.first else { return nil }
        return .share(shareObj.share)
    }

    private func registerObservers() {
        guard let dataSource = dataSource else { return }
        focusObserverToken = dataSource.addFocusObserver { [weak self] in
            self?.handleDataSourceChange()
        }
    }

    private func unregisterObservers() {
        if let token = focusObserverToken {
            dataSource?.removeFocusObserver(token)
            focusObserverToken = nil
        }
    }

    private func handleDataSourceChange() {
        // Sticky camera-off when a previously focused camera disappears.
        if case .camera(let cam) = lastEmitted {
            let rows = dataSource?.remoteCameraSnapshot() ?? []
            if !rows.contains(where: { $0.camera === cam }) {
                let uid = lastCameraUserIds[ObjectIdentifier(cam)] ?? ""
                if !uid.isEmpty {
                    stickyCameraOffUserId = uid
                    debounceWorkItem?.cancel()
                    debounceWorkItem = nil
                    let next = PiPFocusTarget.remoteVideoUnavailable(userId: uid)
                    lastEmitted = next
                    onFocusTargetChanged?(next, false)
                    return
                }
            }
        }
        // Sticky restore when camera returns
        if let sticky = stickyCameraOffUserId {
            let rows = dataSource?.remoteCameraSnapshot() ?? []
            if let row = rows.first(where: { ($0.participant.getId() ?? "") == sticky }) {
                stickyCameraOffUserId = nil
                debounceWorkItem?.cancel()
                debounceWorkItem = nil
                let next = PiPFocusTarget.camera(row.camera)
                lastCameraUserIds[ObjectIdentifier(row.camera)] = sticky
                lastEmitted = next
                onFocusTargetChanged?(next, false)
                return
            }
        }
        scheduleRecompute()
    }

    private func scheduleRecompute() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.emitIfChanged(force: false)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    private func emitIfChanged(force: Bool) {
        let next = computeTarget()
        if !force && isSameTarget(lastEmitted, next) { return }
        if case .camera(let cam) = next {
            if let row = dataSource?.remoteCameraSnapshot().first(where: { $0.camera === cam }) {
                lastCameraUserIds[ObjectIdentifier(cam)] = (row.participant.getId() ?? "")
            }
        }
        lastEmitted = next
        onFocusTargetChanged?(next, force)
    }

    private func isSameTarget(_ lhs: PiPFocusTarget, _ rhs: PiPFocusTarget) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case (.camera(let a), .camera(let b)): return a === b
        case (.share(let a), .share(let b)): return isSameLogicalShare(lhs: a, rhs: b)
        case (.remoteVideoUnavailable(let a), .remoteVideoUnavailable(let b)): return a == b
        default: return false
        }
    }

    private func isSameLogicalShare(lhs: VCRemoteWindowShare, rhs: VCRemoteWindowShare) -> Bool {
        if lhs === rhs { return true }
        let lhsId = lhs.getId() ?? ""
        let rhsId = rhs.getId() ?? ""
        if !lhsId.isEmpty && !rhsId.isEmpty { return lhsId == rhsId }
        return false
    }

    private func computeTarget() -> PiPFocusTarget {
        guard let dataSource = dataSource else { return .none }
        let cameraRows = dataSource.remoteCameraSnapshot()

        if let shareTarget = activeRemoteShareTarget() {
            stickyCameraOffUserId = nil
            return shareTarget
        }

        if let pinnedId = dataSource.pinnedParticipantId, !pinnedId.isEmpty,
           let sticky = stickyCameraOffUserId, sticky != pinnedId {
            stickyCameraOffUserId = nil
        }

        if let sticky = stickyCameraOffUserId {
            if let row = cameraRows.first(where: { ($0.participant.getId() ?? "") == sticky }) {
                stickyCameraOffUserId = nil
                return .camera(row.camera)
            }
            return .remoteVideoUnavailable(userId: sticky)
        }

        if let pinnedId = dataSource.pinnedParticipantId, !pinnedId.isEmpty {
            if let cam = cameraRows.first(where: { ($0.participant.getId() ?? "") == pinnedId })?.camera {
                return .camera(cam)
            }
            return .remoteVideoUnavailable(userId: pinnedId)
        }

        if let loudestId = dataSource.loudestParticipantId, !loudestId.isEmpty {
            if let cam = cameraRows.first(where: { ($0.participant.getId() ?? "") == loudestId })?.camera {
                return .camera(cam)
            }
            return .remoteVideoUnavailable(userId: loudestId)
        }

        if let first = cameraRows.first {
            return .camera(first.camera)
        }

        return .none
    }
}

// MARK: Placeholder view
// Shown in the PiP window when the focused participant has no live remote video
// (camera off / paused). Rasterized to CMSampleBuffer for AVSampleBufferDisplayLayer.

@available(iOS 15.0, *)
fileprivate struct PiPSpeakingState: Equatable {
    let micOn: Bool
    let isSpeaking: Bool
    /// Optional normalized [0...1] level if the audio pipeline exposes it.
    let audioLevel: CGFloat?

    static let inactive = PiPSpeakingState(micOn: false, isSpeaking: false, audioLevel: nil)
}

/// Initials / "only person" placeholder drawn into the PiP sample-buffer pipeline.
@available(iOS 15.0, *)
fileprivate final class PiPRemoteVideoPlaceholderView: UIView {
    private enum RenderMode {
        case participantDisk
        case onlyPersonMessage
    }

    private let diskView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        return iv
    }()
    private var renderMode: RenderMode = .participantDisk

    /// Avoid redundant `UIImage` rebuild when `configure` repeats with the same participant state.
    private var lastConfigureFingerprint: String?

    /// Weak refs for off-screen raster used by PiP capture (same identity as last `configure`).
    private weak var rasterParticipantRef: VCParticipant?
    private var rasterUserId: String = ""
    private var rasterDisplayName: String = ""
    private var rasterSpeakingState: PiPSpeakingState = .inactive

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        addSubview(diskView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = Self.diskSideLength(for: bounds.size)
        diskView.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        diskView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        diskView.layer.cornerRadius = side / 2
        diskView.layer.masksToBounds = true
        diskView.layer.borderWidth = 0
        diskView.layer.borderColor = UIColor.clear.cgColor
    }

    func invalidateRenderedInitialsCache() {
        renderMode = .participantDisk
        lastConfigureFingerprint = nil
        diskView.image = nil
        rasterParticipantRef = nil
        rasterUserId = ""
        rasterDisplayName = ""
        rasterSpeakingState = .inactive
    }

    func configure(participant: VCParticipant, speakingState: PiPSpeakingState = .inactive) {
        renderMode = .participantDisk
        rasterParticipantRef = participant
        rasterUserId = participant.getId() ?? ""
        rasterDisplayName = (participant.name as String?)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        rasterSpeakingState = speakingState

        var rasterSize = bounds.size
        if rasterSize.width < 2 || rasterSize.height < 2 {
            rasterSize = CGSize(width: 320, height: 180)
        }
        let disk = Self.diskSideLength(for: rasterSize)
        let name = rasterDisplayName
        let fingerprint = "p|\(rasterUserId)|\(name)|\(Int(disk * 10))|\(speakingFingerprint(speakingState))"
        if fingerprint == lastConfigureFingerprint, diskView.image != nil {
            return
        }
        lastConfigureFingerprint = fingerprint
        let letters = name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined()
        let initials: String
        if !letters.isEmpty {
            initials = String(letters.prefix(2)).uppercased()
        } else if !name.isEmpty {
            initials = String(name.prefix(2)).uppercased()
        } else {
            initials = "?"
        }
        diskView.image = Self.renderInitialsDiskInterior(side: disk, initials: initials, displayScale: UIScreen.main.scale)
    }

    func configure(userId: String, displayName: String?, speakingState: PiPSpeakingState = .inactive) {
        renderMode = .participantDisk
        rasterParticipantRef = nil
        rasterUserId = userId
        rasterDisplayName = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        rasterSpeakingState = speakingState

        var rasterSize = bounds.size
        if rasterSize.width < 2 || rasterSize.height < 2 {
            rasterSize = CGSize(width: 320, height: 180)
        }
        let disk = Self.diskSideLength(for: rasterSize)
        let name = rasterDisplayName
        let fingerprint = "f|\(userId)|\(name)|\(Int(disk * 10))|\(speakingFingerprint(speakingState))"
        if fingerprint == lastConfigureFingerprint, diskView.image != nil {
            return
        }
        lastConfigureFingerprint = fingerprint
        let letters = name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined()
        let initials: String
        if !letters.isEmpty {
            initials = String(letters.prefix(2)).uppercased()
        } else if !name.isEmpty {
            initials = String(name.prefix(2)).uppercased()
        } else {
            initials = "?"
        }
        diskView.image = Self.renderInitialsDiskInterior(side: disk, initials: initials, displayScale: UIScreen.main.scale)
    }

    func configureOnlyPersonMessage() {
        renderMode = .onlyPersonMessage
        if lastConfigureFingerprint == "only-person-message" {
            return
        }
        lastConfigureFingerprint = "only-person-message"
        diskView.image = nil
        rasterParticipantRef = nil
        rasterUserId = ""
        rasterDisplayName = ""
        rasterSpeakingState = .inactive
    }

    /// Full-frame bitmap for PiP (black 16×9 + stroked avatar disk). Avoids UIView.drawHierarchy transforms.
    func rasterFullFrameBitmap(targetSize: CGSize? = nil) -> UIImage? {
        layoutIfNeeded()
        var rasterSize = targetSize ?? bounds.integral.size
        if rasterSize.width < 2 || rasterSize.height < 2 {
            rasterSize = CGSize(width: 320, height: 180)
        }

        if renderMode == .onlyPersonMessage {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = max(1.0, traitCollection.displayScale > 0.1 ? traitCollection.displayScale : UIScreen.main.scale)
            let renderer = UIGraphicsImageRenderer(size: rasterSize, format: format)
            let headerText = "You're the only person in the call"
            let bodyText = "Waiting for others to join..."
            return renderer.image { _ in
                let full = CGRect(origin: .zero, size: rasterSize)
                UIColor.black.setFill()
                UIRectFill(full)

                let horizontalPadding: CGFloat = 14
                let availableWidth = max(40, rasterSize.width - (horizontalPadding * 2))
                let centerY = rasterSize.height / 2

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center

                let headerFont = UIFont.systemFont(ofSize: min(18, max(13, rasterSize.height * 0.085)), weight: .semibold)
                let bodyFont = UIFont.systemFont(ofSize: min(14, max(11, rasterSize.height * 0.066)), weight: .regular)

                let headerAttr = NSAttributedString(
                    string: headerText,
                    attributes: [
                        .font: headerFont,
                        .foregroundColor: UIColor.white,
                        .paragraphStyle: paragraph
                    ]
                )
                let bodyAttr = NSAttributedString(
                    string: bodyText,
                    attributes: [
                        .font: bodyFont,
                        .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                        .paragraphStyle: paragraph
                    ]
                )

                let boundingSize = CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
                let headerRect = headerAttr.boundingRect(with: boundingSize, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                let bodyRect = bodyAttr.boundingRect(with: boundingSize, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                let spacing: CGFloat = 8
                let totalHeight = ceil(headerRect.height) + spacing + ceil(bodyRect.height)
                let startY = floor(centerY - totalHeight / 2)

                let drawHeader = CGRect(x: horizontalPadding, y: startY, width: availableWidth, height: ceil(headerRect.height))
                let drawBody = CGRect(x: horizontalPadding, y: drawHeader.maxY + spacing, width: availableWidth, height: ceil(bodyRect.height))
                headerAttr.draw(with: drawHeader, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                bodyAttr.draw(with: drawBody, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            }
        }

        let disk = Self.diskSideLength(for: rasterSize)
        let scaleForRenderer = traitCollection.displayScale > 0.1 ? traitCollection.displayScale : UIScreen.main.scale

        let diskContent: UIImage
        if let cachedDisk = diskView.image {
            diskContent = cachedDisk
        } else {
            let name: String
            if let participant = rasterParticipantRef {
                name = (participant.name as String?)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            } else {
                name = rasterDisplayName
            }
            let initials: String
            if let letters = name.getOnlyFirstLetters(), !letters.isEmpty {
                initials = String(letters.prefix(2)).uppercased()
            } else if !name.isEmpty {
                initials = String(name.prefix(2)).uppercased()
            } else {
                initials = "?"
            }
            diskContent = Self.renderInitialsDiskInterior(side: max(disk, 9), initials: initials, displayScale: scaleForRenderer)
        }


        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = max(1.0, scaleForRenderer)
        let renderer = UIGraphicsImageRenderer(size: rasterSize, format: format)

        return renderer.image { _ in
            let full = CGRect(origin: .zero, size: rasterSize)
            UIColor.black.setFill()
            UIRectFill(full)

            let cx = rasterSize.width / 2
            let cy = rasterSize.height / 2
            let diskRect = CGRect(x: cx - disk / 2, y: cy - disk / 2, width: disk, height: disk)

            drawSpeakingEffectIfNeeded(in: diskRect)

            UIColor.black.setFill()
            UIBezierPath(ovalIn: diskRect).fill()
            diskContent.draw(in: diskRect)
        }
    }

    private func speakingFingerprint(_ state: PiPSpeakingState) -> String {
        let levelBucket: Int
        if let level = state.audioLevel {
            levelBucket = Int((max(0, min(1, level)) * 10).rounded())
        } else {
            levelBucket = -1
        }
        return "\(state.micOn ? 1 : 0):\(state.isSpeaking ? 1 : 0):\(levelBucket)"
    }

    private func drawSpeakingEffectIfNeeded(in diskRect: CGRect) {
        guard rasterSpeakingState.micOn else { return }

        let now = CACurrentMediaTime()
        let cycle = now.truncatingRemainder(dividingBy: 1.25) / 1.25
        let pulse = (sin(cycle * .pi * 2) + 1) / 2
        let normalizedLevel = max(0, min(1, rasterSpeakingState.audioLevel ?? (rasterSpeakingState.isSpeaking ? 0.75 : 0.2)))

        let baseScale: CGFloat = 1.14
        let animatedScale: CGFloat = rasterSpeakingState.isSpeaking ? (baseScale + CGFloat(0.05 + (0.10 * normalizedLevel)) * CGFloat(pulse)) : baseScale

        let ringSize = CGSize(width: diskRect.width * animatedScale, height: diskRect.height * animatedScale)
        let ringRect = CGRect(x: diskRect.midX - ringSize.width / 2,
                              y: diskRect.midY - ringSize.height / 2,
                              width: ringSize.width,
                              height: ringSize.height)

        let fillAlpha: CGFloat = rasterSpeakingState.isSpeaking ? (0.16 + 0.14 * CGFloat(pulse)) : 0.09
        let strokeAlpha: CGFloat = rasterSpeakingState.isSpeaking ? (0.70 + 0.25 * CGFloat(pulse)) : 0.40
        let strokeWidth: CGFloat = rasterSpeakingState.isSpeaking ? 3.0 : 2.0
        let blue = UIColor(red: 0.36, green: 0.47, blue: 0.97, alpha: 1.0)

        blue.withAlphaComponent(fillAlpha).setFill()
        UIBezierPath(ovalIn: ringRect).fill()

        let strokePath = UIBezierPath(ovalIn: ringRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2))
        strokePath.lineWidth = strokeWidth
        blue.withAlphaComponent(strokeAlpha).setStroke()
        strokePath.stroke()
    }

    private static func diskSideLength(for bounds: CGSize) -> CGFloat {
        guard bounds.width >= 2, bounds.height >= 2 else { return 120 }
        return min(bounds.width, bounds.height) * 0.44
    }

    private static func initialsString(from contactInitials: String?, name: String) -> String {
        if let i = contactInitials, !i.isEmpty {
            return String(i.prefix(2)).uppercased()
        }
        if let letters = name.getOnlyFirstLetters(), !letters.isEmpty {
            return String(letters.prefix(2)).uppercased()
        }
        return "?"
    }

    /// Light-gray oval + dark-gray initials (square bitmap) to match in-call main screen style.
    private static func renderInitialsDiskInterior(side: CGFloat, initials: String, displayScale: CGFloat) -> UIImage {
        let pxSide = ceil(max(side, 9))
        let size = CGSize(width: pxSide, height: pxSide)
        let format = UIGraphicsImageRendererFormat()
        // Keep transparent corners so outer speaking halo stays visible around the circular avatar.
        format.opaque = false
        format.scale = max(1.0, displayScale)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let text = initials.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let display = text.isEmpty ? "?" : text
        let font = UIFont.systemFont(ofSize: min(pxSide * 0.37, pxSide * 0.52), weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping
        let attributed = NSAttributedString(
            string: display,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: paragraph
            ]
        )
        let textBox = CGSize(width: pxSide - 12, height: CGFloat.greatestFiniteMagnitude)
        let measured = attributed.boundingRect(with: textBox,
                                                 options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                 context: nil)
        let textH = ceil(max(measured.height, font.lineHeight) + 4)
        let textRect = CGRect(x: 6,
                              y: floor((pxSide - textH) / 2),
                              width: pxSide - 12,
                              height: textH)

        return renderer.image { _ in
            UIColor.lightGray.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        }
    }

    private static func renderAvatarDiskInterior(side: CGFloat, source: UIImage, displayScale: CGFloat) -> UIImage {
        let pxSide = ceil(side)
        let size = CGSize(width: pxSide, height: pxSide)
        let format = UIGraphicsImageRendererFormat()
        // Keep transparent corners so outer speaking halo stays visible around the circular avatar.
        format.opaque = false
        format.scale = max(1.0, displayScale)
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.clip()
            let scaleFactor = max(pxSide / source.size.width, pxSide / source.size.height)
            let w = source.size.width * scaleFactor
            let h = source.size.height * scaleFactor
            let x = (pxSide - w) / 2
            let y = (pxSide - h) / 2
            source.draw(in: CGRect(x: x, y: y, width: w, height: h))
        }
    }
}

// MARK: Coordinator, capture and SDK frame bridge
// SystemPiPCoordinator owns AVPictureInPictureController + ContentSource.
// OpenGLFrameCaptureService chooses remote SDK frames vs placeholder raster.
// RemoteCameraSampleBufferBridge converts VCVideoFrame (I420) → NV12 CMSampleBuffer.

@available(iOS 15.0, *)
fileprivate protocol SystemPiPCoordinatorDelegate: AnyObject {
    func systemPiPCoordinator(_ coordinator: SystemPiPCoordinator, didUpdateState active: Bool, canStart: Bool)
    func systemPiPCoordinator(_ coordinator: SystemPiPCoordinator, didFailWith error: Error)
}

/// Owns AVKit PiP controller, sample-buffer display layer, and focus ↔ capture wiring.
@available(iOS 15.0, *)
fileprivate final class SystemPiPCoordinator: NSObject {
    weak var delegate: SystemPiPCoordinatorDelegate?
    /// Fired when the user taps Expand inside the PiP window (return to full call UI).
    var onExpandRequested: (() -> Void)?

    private let captureService = OpenGLFrameCaptureService()
    /// Conference composite view — required by AVKit as the PiP source view.
    private weak var sourceView: UIView?
    private let pipVideoCallViewController = AVPictureInPictureVideoCallViewController()
    private let pipContentView = UIView(frame: .zero)
    private let pipRemotePlaceholderView = PiPRemoteVideoPlaceholderView(frame: .zero)
    private let controlsOverlayView = UIView(frame: .zero)
    private let expandButton = UIButton(type: .system)
    /// Receives NV12 sample buffers that become the PiP video content.
    private let sampleBufferDisplayLayer = AVSampleBufferDisplayLayer()
    private var pipController: AVPictureInPictureController?
    private var pendingStartRequest = false
    private var startRetryCount = 0
    private let maxStartRetries = 6
    private var pendingBackgroundStartOnFirstFrame = false
    private var enqueuedSampleCount: Int64 = 0
    private var droppedSampleCountByEpoch: Int64 = 0
    private var droppedSampleCountByTeardown: Int64 = 0
    private var enqueueDispatchDelayAccumMs: Double = 0
    private var enqueueDispatchDelaySamples: Int64 = 0
    private var shouldStartCaptureAfterPiPDidStart = false
    private var isCaptureRunningForPiP = false
    /// True between background-start request and didStart / failedToStart / stop.
    private var isStartingPiP = false
    private var pipFocusTracker: PiPFocusTracker?
    /// Hard gate to prevent any late/automatic PiP starts during teardown.
    private var pipStartBlocked = false

    private weak var pipDataSource: PiPCallDataSource?
    private var pipFocusObserverToken: AnyObject?

    private var displayLayerStatusObservation: NSKeyValueObservation?
    private var displayLayerErrorObservation: NSKeyValueObservation?
    private var displayLayerObscuredObservation: NSKeyValueObservation?
    /// One-shot layer health dump on the first sample buffer enqueue after PiP starts.
    private var pendingFirstEnqueueLayerHealthLog = false
    /// Dropped immediately when PiP begins dismissing so async enqueues can't extend the teardown and the display layer clears with the dismiss animation.
    private var shouldEnqueueSamplesToPiPDisplayLayer = false
    /// Bumped when PiP is dismissing / restoring so late `main.async` sample callbacks are ignored.
    private var pipSampleBufferEpoch: UInt64 = 0
    private var lastEnqueuePerfLogTs: CFTimeInterval = CACurrentMediaTime()

    private(set) var isActive = false

    /// True only when AVKit reports the system PiP window is actually up (not optimistic willStart).
    var isPictureInPictureActive: Bool {
        pipController?.isPictureInPictureActive == true
    }
    
    var canStartPictureInPicture: Bool {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return false }
        guard let controller = pipController else { return false }
        return controller.isPictureInPicturePossible || !controller.isPictureInPictureActive
    }

    func setPiPStartBlocked(_ blocked: Bool) {
        pipStartBlocked = blocked
    }
    
    init(sourceView: UIView) {
        self.sourceView = sourceView
        super.init()
        
        sampleBufferDisplayLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        configureVideoCallContentView()
        sampleBufferDisplayLayer.flushAndRemoveImage()
        configureDisplayLayerTimebase()
        installDisplayLayerObservers()
        wireRemoteBridgeCallbacks()
        
        captureService.onSampleBuffer = { [weak self] sampleBuffer in
            guard let self = self else { return }
            let epoch = self.pipSampleBufferEpoch
            let submitTs = CACurrentMediaTime()
            DispatchQueue.main.async {
                guard epoch == self.pipSampleBufferEpoch else {
                    self.droppedSampleCountByEpoch += 1
                    self.logEnqueuePerfIfNeeded()
                    return
                }
                guard self.shouldEnqueueSamplesToPiPDisplayLayer else {
                    self.droppedSampleCountByTeardown += 1
                    self.logEnqueuePerfIfNeeded()
                    return
                }
                let delayMs = max(0, (CACurrentMediaTime() - submitTs) * 1000)
                self.enqueueDispatchDelayAccumMs += delayMs
                self.enqueueDispatchDelaySamples += 1
                self.updateSampleLayerFrame()
                self.recoverDisplayLayerIfNeeded()
                if self.pendingFirstEnqueueLayerHealthLog {
                    self.pendingFirstEnqueueLayerHealthLog = false
                    let needsFlush = self.sampleBufferDisplayLayer.requiresFlushToResumeDecoding
                    pipLogInfo("System PiP first enqueue after start: layerStatus=\(self.sampleBufferDisplayLayer.status.rawValue) requiresFlushToResumeDecoding=\(needsFlush)")
                }
                self.sampleBufferDisplayLayer.enqueue(sampleBuffer)
                self.enqueuedSampleCount += 1
                self.logEnqueuePerfIfNeeded()
            }
        }
        captureService.onFirstSample = { [weak self] in
            DispatchQueue.main.async {
                self?.attemptBackgroundStartWhenFrameReady(trigger: "first-sample")
            }
        }
        configurePiPController()
    }

    deinit {
        if let token = pipFocusObserverToken {
            pipDataSource?.removeFocusObserver(token)
            pipFocusObserverToken = nil
        }
        displayLayerStatusObservation?.invalidate()
        displayLayerErrorObservation?.invalidate()
        displayLayerObscuredObservation?.invalidate()
    }

    private func wireRemoteBridgeCallbacks() {
        captureService.remoteSampleBufferBridge.onPeriodicDisplayLayerHealthCheck = { [weak self] in
            guard self?.shouldEnqueueSamplesToPiPDisplayLayer == true else { return }
            self?.recoverDisplayLayerIfNeeded()
        }
    }

    private func installDisplayLayerObservers() {
        displayLayerStatusObservation = sampleBufferDisplayLayer.observe(\.status, options: [.new]) { [weak self] _, _ in
            self?.scheduleRecoverDisplayLayerIfNeeded()
        }
        displayLayerErrorObservation = sampleBufferDisplayLayer.observe(\.error, options: [.new]) { [weak self] _, _ in
            self?.scheduleRecoverDisplayLayerIfNeeded()
        }
        displayLayerObscuredObservation = sampleBufferDisplayLayer.observe(\.isOutputObscuredDueToInsufficientExternalProtection, options: [.new]) { [weak self] _, _ in
            self?.scheduleRecoverDisplayLayerIfNeeded()
        }
    }

    private func scheduleRecoverDisplayLayerIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            self?.recoverDisplayLayerIfNeeded()
        }
    }

    private func recoverDisplayLayerIfNeeded() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.recoverDisplayLayerIfNeeded() }
            return
        }
        guard shouldEnqueueSamplesToPiPDisplayLayer else { return }
        let layer = sampleBufferDisplayLayer
        let status = layer.status
        let errDesc = layer.error?.localizedDescription ?? "nil"
        let needsFlush = layer.requiresFlushToResumeDecoding
        let obscured = layer.isOutputObscuredDueToInsufficientExternalProtection

        // Avoid flushing when `requiresFlushToResumeDecoding` is alone: it stays true across normal PiP/placeholder playback
        // on some builds; flushing before every enqueue causes visible initials flicker.
        let needsRecovery = layer.status == .failed || layer.error != nil

        if needsRecovery {
            pipLogWarning("System PiP display layer recovery: status=\(status.rawValue) error=\(errDesc) requiresFlushToResumeDecoding=\(needsFlush) obscured=\(obscured)")
            layer.flush()
            pipFocusTracker?.recomputeNow()
        }
    }

    /// Bump so any in-flight `captureService.onSampleBuffer` `main.async` work is dropped (stale placeholder/lag).
    private func bumpPiPSampleBufferEpochForTeardown() {
        pipSampleBufferEpoch &+= 1
    }

    private func logEnqueuePerfIfNeeded() {
        let now = CACurrentMediaTime()
        let interval = now - lastEnqueuePerfLogTs
        guard interval >= 5.0 else { return }
        lastEnqueuePerfLogTs = now
        let avgDispatchDelayMs = enqueueDispatchDelaySamples > 0 ? (enqueueDispatchDelayAccumMs / Double(enqueueDispatchDelaySamples)) : 0
        pipLogInfo("System PiP enqueue metrics: enqueued=\(enqueuedSampleCount) droppedEpoch=\(droppedSampleCountByEpoch) droppedTeardown=\(droppedSampleCountByTeardown) avgDispatchDelayMs=\(String(format: "%.2f", avgDispatchDelayMs))")
        enqueueDispatchDelayAccumMs = 0
        enqueueDispatchDelaySamples = 0
    }

    /// Call once call-state dependencies exist so PiP can mirror the focused tile (pinned / share / loudest).
    func configurePiPFocusDependencies(dataSource: PiPCallDataSource) {
        wireRemoteBridgeCallbacks()
        pipDataSource = dataSource
        if pipFocusObserverToken == nil {
            pipFocusObserverToken = dataSource.addFocusObserver { [weak self] in
                self?.captureService.refreshPiPCaptureMode()
            }
        }

        let focusChanged: (PiPFocusTarget, Bool) -> Void = { [weak self] target, force in
            self?.captureService.remoteSampleBufferBridge.applyFocusTarget(target, force: force) { [weak self] in
                self?.captureService.refreshPiPCaptureMode()
            }
        }

        if let tracker = pipFocusTracker {
            tracker.onFocusTargetChanged = focusChanged
            captureService.onPiPPlaceholderUnderlayVisible = { [weak self] visible in
                self?.pipRemotePlaceholderView.isHidden = !visible
            }
            captureService.configurePiPPlaceholderDependencies(
                placeholderView: pipRemotePlaceholderView,
                focusTracker: tracker,
                dataSource: dataSource
            )
            captureService.remoteSampleBufferBridge.dataSource = dataSource
            captureService.remoteSampleBufferBridge.onAttachmentRequiresDisplayFlush = { [weak self] in
                DispatchQueue.main.async {
                    self?.sampleBufferDisplayLayer.flushAndRemoveImage()
                }
            }
            captureService.remoteSampleBufferBridge.stallRecoveryHandler = { [weak self] in
                self?.pipFocusTracker?.recomputeNow()
            }
            return
        }
        let tracker = PiPFocusTracker(dataSource: dataSource)
        tracker.onFocusTargetChanged = focusChanged
        pipFocusTracker = tracker
        captureService.onPiPPlaceholderUnderlayVisible = { [weak self] visible in
            self?.pipRemotePlaceholderView.isHidden = !visible
        }
        captureService.configurePiPPlaceholderDependencies(
            placeholderView: pipRemotePlaceholderView,
            focusTracker: tracker,
            dataSource: dataSource
        )
        captureService.remoteSampleBufferBridge.dataSource = dataSource
        captureService.remoteSampleBufferBridge.onAttachmentRequiresDisplayFlush = { [weak self] in
            DispatchQueue.main.async {
                self?.sampleBufferDisplayLayer.flushAndRemoveImage()
            }
        }
        captureService.remoteSampleBufferBridge.stallRecoveryHandler = { [weak self] in
            self?.pipFocusTracker?.recomputeNow()
        }
    }

    func updateSourceView(_ sourceView: UIView, forceRebuild: Bool = false) {
        let isSameView = (self.sourceView === sourceView)
        self.sourceView = sourceView

        if !forceRebuild {
            // Never tear down / rebuild while PiP is starting or already showing.
            // A delayed `refreshVideoView` used to hit this path on the first Home swipe,
            // stop the new PiP session, and restore the app to the foreground.
            if isActive || isStartingPiP || pipController?.isPictureInPictureActive == true {
                pipLogInfo("System PiP updateSourceView skipped: active/starting")
                return
            }

            // Same composite view + existing controller: keep the warm AVKit session.
            if isSameView, pipController != nil {
                return
            }
        }

        // Soft-stop first if needed, then replace the controller (NeoIOS pattern).
        // Dropping the old controller releases a stuck system bubble; never detach contentSource.
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        configurePiPController()
    }
    
    func togglePictureInPicture() {
        if isActive {
            stopPictureInPicture(force: false)
        } else {
            startPictureInPicture()
        }
    }
    
    func startPictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard let sourceView = sourceView else { return }
        guard !pipStartBlocked else {
            pipLogInfo("System PiP start ignored: blocked by teardown guard")
            return
        }

        applyPiPVideoWellBacking(opaqueBlack: true)
        shouldEnqueueSamplesToPiPDisplayLayer = true
        pendingFirstEnqueueLayerHealthLog = true
        captureService.startCapturing(from: sourceView)
        pipFocusTracker?.start()
        captureService.refreshPiPCaptureMode()
        pendingStartRequest = true
        startRetryCount = 0
        
        // Allow initial sample-buffer enqueue, then start with readiness retries.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.attemptStartPictureInPicture()
        }
    }
    
    func startPictureInPictureForBackgroundTransition() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard let sourceView = sourceView else { return }
        guard !pipStartBlocked else {
            pipLogInfo("System PiP background start ignored: blocked by teardown guard")
            return
        }
        
        pendingStartRequest = false
        startRetryCount = 0
        pendingBackgroundStartOnFirstFrame = false
        shouldStartCaptureAfterPiPDidStart = true
        isStartingPiP = true
        
        let sceneState = sourceView.window?.windowScene?.activationState.rawValue ?? -1
        let appState = UIApplication.shared.applicationState.rawValue
        pipLogInfo("System PiP background start: immediate request, appState=\(appState), sceneState=\(sceneState), possible=\(pipController?.isPictureInPicturePossible == true)")
        applyPiPVideoWellBacking(opaqueBlack: true)
        shouldEnqueueSamplesToPiPDisplayLayer = true
        // No manual startPictureInPicture(): calling it mid Home-gesture makes iOS cancel the gesture
        // (PiP opens over a foreground app). canStartPictureInPictureAutomaticallyFromInline starts PiP
        // as part of the gesture, and willStart marks the active state.
    }
    
    /// Bounce / cancelled Home: drop optimistic mid-start state without calling
    /// `stopPictureInPicture()` (that races AVKit and flashes the first swipe off).
    func clearInFlightStartWithoutStoppingController() {
        guard pipController?.isPictureInPictureActive != true else { return }
        pendingStartRequest = false
        pendingBackgroundStartOnFirstFrame = false
        shouldStartCaptureAfterPiPDidStart = false
        isStartingPiP = false
        if isActive {
            isActive = false
            applyPiPVideoWellBacking(opaqueBlack: false)
            delegate?.systemPiPCoordinator(self, didUpdateState: false, canStart: canStartPictureInPicture)
        }
        pipLogInfo("System PiP cleared in-flight start without stopping controller")
    }

    func stopPictureInPicture(force: Bool) {
        pendingStartRequest = false
        pendingBackgroundStartOnFirstFrame = false
        shouldStartCaptureAfterPiPDidStart = false
        isStartingPiP = false
        bumpPiPSampleBufferEpochForTeardown()
        shouldEnqueueSamplesToPiPDisplayLayer = false
        isCaptureRunningForPiP = false
        if force {
            pipFocusTracker?.stop()
            captureService.stopCapturing()
            hidePiPUnderlyingPlaceholderDiskIfShowingLiveFrames()
            sampleBufferDisplayLayer.flushAndRemoveImage()
        }
        
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
            if force {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self = self else { return }
                    if self.pipController?.isPictureInPictureActive == true {
                        self.pipController?.stopPictureInPicture()
                    }
                }
            }
        } else {
            isActive = false
            applyPiPVideoWellBacking(opaqueBlack: false)
            delegate?.systemPiPCoordinator(self, didUpdateState: false, canStart: canStartPictureInPicture)
        }
    }
    
    func stopPictureInPictureForForegroundReturn() {
        bumpPiPSampleBufferEpochForTeardown()
        shouldEnqueueSamplesToPiPDisplayLayer = false
        let dismiss = { [weak self] in
            guard let self = self else { return }
            self.hidePiPUnderlyingPlaceholderDiskIfShowingLiveFrames()
            self.sampleBufferDisplayLayer.flushAndRemoveImage()
            self.pipController?.stopPictureInPicture()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                if self.pipController?.isPictureInPictureActive == true {
                    self.pipController?.stopPictureInPicture()
                }
            }
        }
        if Thread.isMainThread {
            dismiss()
        } else {
            DispatchQueue.main.async(execute: dismiss)
        }
    }

    /// Hard teardown path for call-end dismissal; prevents orphan PiP sessions from surviving VC teardown.
    func invalidateForCallTeardown() {
        pipStartBlocked = true
        pendingStartRequest = false
        pendingBackgroundStartOnFirstFrame = false
        shouldStartCaptureAfterPiPDidStart = false
        isStartingPiP = false
        bumpPiPSampleBufferEpochForTeardown()
        shouldEnqueueSamplesToPiPDisplayLayer = false
        isCaptureRunningForPiP = false
        pipFocusTracker?.stop()
        captureService.stopCapturing()
        hidePiPUnderlyingPlaceholderDiskIfShowingLiveFrames()
        sampleBufferDisplayLayer.flushAndRemoveImage()
        if pipController?.isPictureInPictureActive == true {
            pipController?.stopPictureInPicture()
        }
        pipController?.delegate = nil
        pipController = nil
        isActive = false
        applyPiPVideoWellBacking(opaqueBlack: false)
        delegate?.systemPiPCoordinator(self, didUpdateState: false, canStart: false)
    }
    
    private func configurePiPController() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        guard let sourceView = sourceView else { return }
        let contentSource = AVPictureInPictureController.ContentSource(activeVideoCallSourceView: sourceView,
                                                                       contentViewController: pipVideoCallViewController)
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
    }
    
    private func configureVideoCallContentView() {
        pipVideoCallViewController.view.backgroundColor = .clear
        // Keep PiP window in a realistic 16:9 content size hint.
        pipVideoCallViewController.preferredContentSize = CGSize(width: 320, height: 180)
        pipContentView.backgroundColor = .clear
        pipContentView.translatesAutoresizingMaskIntoConstraints = false
        pipRemotePlaceholderView.isHidden = true
        pipVideoCallViewController.view.addSubview(pipContentView)
        NSLayoutConstraint.activate([
            pipContentView.leadingAnchor.constraint(equalTo: pipVideoCallViewController.view.leadingAnchor),
            pipContentView.trailingAnchor.constraint(equalTo: pipVideoCallViewController.view.trailingAnchor),
            pipContentView.topAnchor.constraint(equalTo: pipVideoCallViewController.view.topAnchor),
            pipContentView.bottomAnchor.constraint(equalTo: pipVideoCallViewController.view.bottomAnchor)
        ])
        pipRemotePlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        pipVideoCallViewController.view.insertSubview(pipRemotePlaceholderView, belowSubview: pipContentView)
        NSLayoutConstraint.activate([
            pipRemotePlaceholderView.centerXAnchor.constraint(equalTo: pipVideoCallViewController.view.centerXAnchor),
            pipRemotePlaceholderView.centerYAnchor.constraint(equalTo: pipVideoCallViewController.view.centerYAnchor),
            pipRemotePlaceholderView.widthAnchor.constraint(equalToConstant: 320),
            pipRemotePlaceholderView.heightAnchor.constraint(equalToConstant: 180)
        ])
        pipContentView.layer.addSublayer(sampleBufferDisplayLayer)
        updateSampleLayerFrame()
        configureControlsOverlay()
    }

    /// Opaque backing so flushing `sampleBufferDisplayLayer` does not reveal `pipRemotePlaceholderView` underneath.
    private func applyPiPVideoWellBacking(opaqueBlack: Bool) {
        pipContentView.backgroundColor = opaqueBlack ? .black : .clear
    }

    /// Before clearing `AVSampleBufferDisplayLayer`, hide the UILabel-backed disk when PiP encoding is meant to mirror live frames.
    private func hidePiPUnderlyingPlaceholderDiskIfShowingLiveFrames() {
        guard !captureService.isPlaceholderCaptureMode else { return }
        pipRemotePlaceholderView.isHidden = true
    }
    
    private func updateSampleLayerFrame() {
        let targetBounds = pipContentView.bounds
        guard targetBounds.width > 0, targetBounds.height > 0 else { return }
        if sampleBufferDisplayLayer.frame != targetBounds {
            sampleBufferDisplayLayer.frame = targetBounds
        }
    }
    
    private func configureControlsOverlay() {
        controlsOverlayView.backgroundColor = .clear
        controlsOverlayView.isUserInteractionEnabled = true
        controlsOverlayView.translatesAutoresizingMaskIntoConstraints = false
        pipVideoCallViewController.view.addSubview(controlsOverlayView)
        NSLayoutConstraint.activate([
            controlsOverlayView.leadingAnchor.constraint(equalTo: pipVideoCallViewController.view.leadingAnchor),
            controlsOverlayView.trailingAnchor.constraint(equalTo: pipVideoCallViewController.view.trailingAnchor),
            controlsOverlayView.topAnchor.constraint(equalTo: pipVideoCallViewController.view.topAnchor),
            controlsOverlayView.bottomAnchor.constraint(equalTo: pipVideoCallViewController.view.bottomAnchor)
        ])

        configureExpandIconButton()
        expandButton.addTarget(self, action: #selector(onExpandTapped), for: .touchUpInside)
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        controlsOverlayView.addSubview(expandButton)

        NSLayoutConstraint.activate([
            expandButton.trailingAnchor.constraint(equalTo: controlsOverlayView.trailingAnchor, constant: -10),
            expandButton.topAnchor.constraint(equalTo: controlsOverlayView.topAnchor, constant: 10),
            expandButton.widthAnchor.constraint(equalToConstant: 36),
            expandButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    /// PiP toolbar: circular control with SF Symbol (“expand back to full call” cue used across iOS).
    private func configureExpandIconButton() {
        expandButton.adjustsImageWhenHighlighted = false
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        let icon = UIImage(systemName: "viewfinder", withConfiguration: symbolConfig)
        expandButton.setImage(icon, for: .normal)
        expandButton.setTitle(nil, for: .normal)
        expandButton.imageView?.contentMode = .scaleAspectFit
        expandButton.tintColor = .white
        expandButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        expandButton.layer.cornerRadius = 18
        expandButton.layer.masksToBounds = true
        expandButton.accessibilityLabel = NSLocalizedString("Expand", comment: "Picture-in-Picture: return call to fullscreen")
    }

    @objc private func onExpandTapped() {
        onExpandRequested?()
    }
    
    private func configureDisplayLayerTimebase() {
        // Live PiP: use no control timebase so each buffer is shown as soon as it is enqueued.
        // A host-clock timebase + host PTS from consecutive frames can duplicate or go backwards and stall the layer.
        sampleBufferDisplayLayer.controlTimebase = nil
    }
    
    private func attemptStartPictureInPicture() {
        guard pendingStartRequest else { return }
        guard !pipStartBlocked else {
            pendingStartRequest = false
            pipLogInfo("System PiP start attempt canceled: blocked by teardown guard")
            return
        }
        guard let controller = pipController else { return }
        guard !controller.isPictureInPictureActive else {
            pendingStartRequest = false
            return
        }
        
        if controller.isPictureInPicturePossible {
            pendingStartRequest = false
            pipLogInfo("System PiP start attempt \(startRetryCount + 1): possible=true, starting")
            controller.startPictureInPicture()
            return
        }
        
        startRetryCount += 1
        guard startRetryCount <= maxStartRetries else {
            pendingStartRequest = false
            pipLogError("System PiP start aborted: possible=false after \(maxStartRetries) retries")
            return
        }
        
        pipLogInfo("System PiP start attempt \(startRetryCount): possible=false, retrying")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.attemptStartPictureInPicture()
        }
    }
    
    private func attemptBackgroundStartWhenFrameReady(trigger: String) {
        // Retained for diagnostic compatibility; background flow starts immediately.
        pipLogInfo("System PiP background first-sample callback received (ignored), trigger=\(trigger)")
    }
}

@available(iOS 15.0, *)
extension SystemPiPCoordinator: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        if pipStartBlocked {
            pipLogInfo("System PiP will-start ignored: blocked by teardown guard")
            pictureInPictureController.stopPictureInPicture()
            return
        }
        pipLogInfo("System PiP will start")
        applyPiPVideoWellBacking(opaqueBlack: true)
        shouldEnqueueSamplesToPiPDisplayLayer = true
        pendingFirstEnqueueLayerHealthLog = true
        if !isCaptureRunningForPiP, let sourceView = sourceView {
            isCaptureRunningForPiP = true
            captureService.startCapturing(from: sourceView)
            pipFocusTracker?.start()
            captureService.refreshPiPCaptureMode()
        }
        // Mark active-intent early so app background transition keeps renderer alive.
        if !isActive {
            isActive = true
            delegate?.systemPiPCoordinator(self, didUpdateState: true, canStart: canStartPictureInPicture)
        }
    }
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pendingStartRequest = false
        pendingBackgroundStartOnFirstFrame = false
        isStartingPiP = false
        pendingFirstEnqueueLayerHealthLog = true
        shouldEnqueueSamplesToPiPDisplayLayer = true
        pipLogInfo("System PiP did start")
        shouldStartCaptureAfterPiPDidStart = false
        if !isCaptureRunningForPiP, let sourceView = sourceView {
            isCaptureRunningForPiP = true
            captureService.startCapturing(from: sourceView)
            pipFocusTracker?.start()
            captureService.refreshPiPCaptureMode()
        }
        isActive = true
        delegate?.systemPiPCoordinator(self, didUpdateState: true, canStart: canStartPictureInPicture)
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipLogInfo("System PiP will stop")
        isStartingPiP = false
        bumpPiPSampleBufferEpochForTeardown()
        hidePiPUnderlyingPlaceholderDiskIfShowingLiveFrames()
        shouldEnqueueSamplesToPiPDisplayLayer = false
        sampleBufferDisplayLayer.flushAndRemoveImage()
        isCaptureRunningForPiP = false
        pipFocusTracker?.stop()
        captureService.stopCapturing()
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipLogInfo("System PiP did stop")
        isStartingPiP = false
        bumpPiPSampleBufferEpochForTeardown()
        applyPiPVideoWellBacking(opaqueBlack: false)
        shouldEnqueueSamplesToPiPDisplayLayer = false
        sampleBufferDisplayLayer.flushAndRemoveImage()
        isActive = false
        delegate?.systemPiPCoordinator(self, didUpdateState: false, canStart: canStartPictureInPicture)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                 restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        // User tapped the PiP window to return to the app — stop enqueueing frames and clear the layer immediately
        // so the stale placeholder / mask does not linger over live video until the controller fully stops.
        bumpPiPSampleBufferEpochForTeardown()
        hidePiPUnderlyingPlaceholderDiskIfShowingLiveFrames()
        shouldEnqueueSamplesToPiPDisplayLayer = false
        sampleBufferDisplayLayer.flushAndRemoveImage()
        completionHandler(true)
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                 failedToStartPictureInPictureWithError error: Error) {
        pendingStartRequest = false
        pendingBackgroundStartOnFirstFrame = false
        shouldStartCaptureAfterPiPDidStart = false
        isStartingPiP = false
        bumpPiPSampleBufferEpochForTeardown()
        applyPiPVideoWellBacking(opaqueBlack: false)
        shouldEnqueueSamplesToPiPDisplayLayer = false
        isCaptureRunningForPiP = false
        pipFocusTracker?.stop()
        captureService.stopCapturing()
        sampleBufferDisplayLayer.flushAndRemoveImage()
        isActive = false
        delegate?.systemPiPCoordinator(self, didFailWith: error)
    }
}

@available(iOS 15.0, *)
extension SystemPiPCoordinator: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    setPlaying playing: Bool) {
        // Video-call PiP is driven by live camera/placeholder frames, not AVKit-style pause/resume.
        // Treating `playing == false` as "paused" used to drop all sample buffers on the home screen
        // (black PiP) while controls still showed.
    }
    
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: CMTime.zero, duration: CMTime.positiveInfinity)
    }
    
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        // Always "playing" so AVKit does not suppress sample-buffer delivery for active video-call PiP.
        return false
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    skipByInterval skipInterval: CMTime,
                                    completion: @escaping () -> Void) {
        completion()
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController,
                                    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        DispatchQueue.main.async { [weak self] in
            self?.updateSampleLayerFrame()
        }
    }
}

/// Routes PiP pixels: live remote frames (via bridge) or placeholder raster when video is unavailable.
@available(iOS 15.0, *)
fileprivate final class OpenGLFrameCaptureService {
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?
    var onFirstSample: (() -> Void)?
    private static let captureDeviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()

    private weak var sourceView: UIView?
    private weak var pipPlaceholderView: PiPRemoteVideoPlaceholderView?
    private weak var pipFocusTracker: PiPFocusTracker?
    private weak var dataSource: PiPCallDataSource?
    private var registeredPiPParticipantsObserver = false
    private var registeredPiPMicObserver = false
    private var registeredPiPLoudestObserver = false

    private var displayLink: CADisplayLink?
    private var placeholderDisplayLink: CADisplayLink?
    private var pixelBufferPool: CVPixelBufferPool?
    private var formatDescription: CMVideoFormatDescription?

    private let captureQueue = DispatchQueue(label: "com.vidyo.systempip.capture.queue", qos: .userInitiated)
    private let defaultLiveCaptureFPS = 12
    private let defaultPlaceholderFPS = 10
    private let throttledPiPFPS = 8
    private let adaptivePiPFPSEnabled = true
    private let enableMainThreadSnapshotOptimization = true
    /// Monotonic PTS for placeholder frames (`AVSampleBufferDisplayLayer`; host-clock PTS jitter can force decode recovery / flicker).
    private let placeholderPresentationTimescale: Int32 = 60_000
    /// Derived from active placeholder FPS (`timescale / fps`) to keep monotonic PTS stable.
    private var placeholderTicksPerFrame: Int64 = 4_000
    private var nextPlaceholderPresentationTicks: Int64 = 0
    private let remoteFrameBridge = RemoteCameraSampleBufferBridge()
    /// Exposes the bridge for PiP focus routing (`PiPFocusTracker`).
    var remoteSampleBufferBridge: RemoteCameraSampleBufferBridge { remoteFrameBridge }
    /// Mirrors `PiPRemoteVideoPlaceholderView` visibility: `true` only while rasterizing initials for PiP (hide under flushed `AVSampleBufferDisplayLayer`).
    var onPiPPlaceholderUnderlayVisible: ((Bool) -> Void)?
    private var receivingRemoteFrames = false
    private(set) var hasProducedFirstSample = false
    private let useViewFallbackCapture = false

    private var isCapturing = false
    /// Writable only from PiP routing on the main queue; readable for coordinator restore/stop sequencing.
    private(set) var isPlaceholderCaptureMode = false
    /// True when Y-plane looks like sustained black (SDK often omits `VCDeviceState` pause for remote camera off).
    private var remoteVideoInactiveFromBlackFrames = false
    private var activeLiveCaptureFPS: Int = 12
    private var activePlaceholderFPS: Int = 10
    private var lastAdaptivePolicyCheckTs: CFTimeInterval = 0
    private var captureFrameCount: Int64 = 0
    private var captureFrameTimeAccumMs: Double = 0
    private var placeholderRasterFrameCount: Int64 = 0
    private var lastCapturePerfLogTs: CFTimeInterval = CACurrentMediaTime()
    private let speakingIndicatorFeatureEnabled = true
    /// Supersample placeholder bitmaps to reduce text/initials blur in PiP (balanced for CPU).
    private let placeholderSupersampleScale: CGFloat = 1.5

    func configurePiPPlaceholderDependencies(placeholderView: PiPRemoteVideoPlaceholderView,
                                             focusTracker: PiPFocusTracker,
                                             dataSource: PiPCallDataSource) {
        pipPlaceholderView = placeholderView
        pipFocusTracker = focusTracker
        self.dataSource = dataSource
        registerSpeakingSignalObserversIfNeeded()
        remoteFrameBridge.onRemoteVideoLikelyInactive = { [weak self] inactive in
            self?.remoteVideoInactiveFromBlackFrames = inactive
            self?.refreshPiPCaptureMode()
        }
        refreshPiPCaptureMode()
    }

    func refreshPiPCaptureMode() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshPiPCaptureModeOnMain()
        }
    }

    private func preparePlaceholderLayout(_ placeholderView: PiPRemoteVideoPlaceholderView) {
        placeholderView.superview?.setNeedsLayout()
        placeholderView.superview?.layoutIfNeeded()
        placeholderView.layoutIfNeeded()
    }

    private func showOnlyPersonPlaceholder(_ placeholderView: PiPRemoteVideoPlaceholderView) {
        preparePlaceholderLayout(placeholderView)
        placeholderView.configureOnlyPersonMessage()
        placeholderView.layoutIfNeeded()
        onPiPPlaceholderUnderlayVisible?(true)
        if !isPlaceholderCaptureMode {
            pipLogInfo("System PiP: placeholder capture (only-person message)")
            isPlaceholderCaptureMode = true
            receivingRemoteFrames = false
            remoteVideoInactiveFromBlackFrames = false
            remoteFrameBridge.setPlaceholderCaptureActive(true)
            startPlaceholderDisplayLink()
        }
    }

    private func registerSpeakingSignalObserversIfNeeded() {
        guard !registeredPiPParticipantsObserver, let dataSource = dataSource else { return }
        _ = dataSource.addFocusObserver { [weak self] in
            self?.refreshPiPCaptureMode()
        }
        registeredPiPParticipantsObserver = true
        registeredPiPMicObserver = true
        registeredPiPLoudestObserver = true
    }

    private func speakingState(for focusedUserId: String) -> PiPSpeakingState {
        guard speakingIndicatorFeatureEnabled, !focusedUserId.isEmpty else {
            return .inactive
        }
        guard let dataSource = dataSource else { return .inactive }
        let micOn = dataSource.isRemoteMicOn(userId: focusedUserId)
        let loudestId = dataSource.loudestParticipantId ?? ""
        let isSpeaking = micOn && !loudestId.isEmpty && loudestId == focusedUserId
        return PiPSpeakingState(micOn: micOn, isSpeaking: isSpeaking, audioLevel: nil)
    }

    private func placeholderTicks(for fps: Int) -> Int64 {
        let clamped = max(1, fps)
        return Int64(placeholderPresentationTimescale) / Int64(clamped)
    }

    private func computeAdaptiveTargetFPS() -> (live: Int, placeholder: Int) {
        guard adaptivePiPFPSEnabled else {
            return (defaultLiveCaptureFPS, defaultPlaceholderFPS)
        }
        let thermal = ProcessInfo.processInfo.thermalState
        let appState = UIApplication.shared.applicationState
        let shouldThrottle = appState != .active || thermal == .serious || thermal == .critical
        if shouldThrottle {
            return (throttledPiPFPS, throttledPiPFPS)
        }
        return (defaultLiveCaptureFPS, defaultPlaceholderFPS)
    }

    private func applyAdaptivePiPFrameRatePolicyIfNeeded(force: Bool = false) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.applyAdaptivePiPFrameRatePolicyIfNeeded(force: force)
            }
            return
        }

        let now = CACurrentMediaTime()
        if !force, now - lastAdaptivePolicyCheckTs < 2.0 {
            return
        }
        lastAdaptivePolicyCheckTs = now

        let target = computeAdaptiveTargetFPS()
        if force || target.live != activeLiveCaptureFPS {
            activeLiveCaptureFPS = target.live
            remoteFrameBridge.setTargetFrameRate(target.live)
        }
        if force || target.placeholder != activePlaceholderFPS {
            activePlaceholderFPS = target.placeholder
            placeholderTicksPerFrame = placeholderTicks(for: target.placeholder)
            if let link = placeholderDisplayLink, link.preferredFramesPerSecond != target.placeholder {
                link.preferredFramesPerSecond = target.placeholder
            }
        }
    }

    func startCapturing(from sourceView: UIView) {
        self.sourceView = sourceView
        stopPlaceholderDisplayLinkIfNeeded()
        stopDisplayLinkIfNeeded()
        applyAdaptivePiPFrameRatePolicyIfNeeded(force: true)
        receivingRemoteFrames = false
        hasProducedFirstSample = false
        isCapturing = true
        isPlaceholderCaptureMode = false
        captureFrameCount = 0
        captureFrameTimeAccumMs = 0
        placeholderRasterFrameCount = 0
        lastCapturePerfLogTs = CACurrentMediaTime()
        remoteFrameBridge.start { [weak self] sampleBuffer in
            guard let self = self else { return }
            guard !self.isPlaceholderCaptureMode else { return }
            self.receivingRemoteFrames = true
            self.emit(sampleBuffer: sampleBuffer)
        }

        if useViewFallbackCapture {
            let displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLinkTick))
            displayLink.preferredFramesPerSecond = activeLiveCaptureFPS
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
    }

    func stopCapturing() {
        isCapturing = false
        isPlaceholderCaptureMode = false
        stopPlaceholderDisplayLinkIfNeeded()
        stopDisplayLinkIfNeeded()
        receivingRemoteFrames = false
        hasProducedFirstSample = false
        remoteFrameBridge.stop()
        pixelBufferPool = nil
        formatDescription = nil
        sourceView = nil
        onPiPPlaceholderUnderlayVisible?(false)
    }

    private func stopDisplayLinkIfNeeded() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func stopPlaceholderDisplayLinkIfNeeded() {
        placeholderDisplayLink?.invalidate()
        placeholderDisplayLink = nil
    }

    @objc private func onDisplayLinkTick() {
        applyAdaptivePiPFrameRatePolicyIfNeeded()
        captureQueue.async { [weak self] in
            self?.captureFrame()
        }
    }

    @objc private func onPlaceholderDisplayLinkTick() {
        guard isPlaceholderCaptureMode else { return }
        applyAdaptivePiPFrameRatePolicyIfNeeded()
        captureQueue.async { [weak self] in
            self?.captureFrame()
        }
    }

    private func startPlaceholderDisplayLink() {
        guard placeholderDisplayLink == nil else { return }
        applyAdaptivePiPFrameRatePolicyIfNeeded(force: true)
        nextPlaceholderPresentationTicks = 0
        let link = CADisplayLink(target: self, selector: #selector(onPlaceholderDisplayLinkTick))
        link.preferredFramesPerSecond = activePlaceholderFPS
        link.add(to: .main, forMode: .common)
        placeholderDisplayLink = link
    }

    private func refreshPiPCaptureModeOnMain() {
        guard isCapturing else {
            return
        }
        applyAdaptivePiPFrameRatePolicyIfNeeded()
        guard let placeholderView = pipPlaceholderView,
              let focusTracker = pipFocusTracker,
              let dataSource = dataSource else {
            exitPiPPlaceholderCaptureModeIfNeeded()
            return
        }

        let focus = focusTracker.currentFocusTarget
        let hasActiveRemoteParticipant = dataSource.hasActiveRemoteParticipant()

        if !hasActiveRemoteParticipant {
            if case .share = focus {
                // Keep share path while share focus is active.
            } else {
                showOnlyPersonPlaceholder(placeholderView)
                return
            }
        }

        switch focus {
        case .camera(let cam):
            let cameraRows = dataSource.remoteCameraSnapshot()
            guard let entry = cameraRows.first(where: { $0.camera === cam }) else {
                exitPiPPlaceholderCaptureModeIfNeeded()
                return
            }
            let showPlaceholder = entry.isPaused || remoteVideoInactiveFromBlackFrames
            let participantId = entry.participant.getId() ?? ""
            let speakingState = speakingState(for: participantId)

            if showPlaceholder {
                preparePlaceholderLayout(placeholderView)
                placeholderView.configure(participant: entry.participant, speakingState: speakingState)
                placeholderView.layoutIfNeeded()
                onPiPPlaceholderUnderlayVisible?(true)
                if !isPlaceholderCaptureMode {
                    pipLogInfo("System PiP: placeholder capture on userId=\(participantId) sdkPaused=\(entry.isPaused) blackInactive=\(remoteVideoInactiveFromBlackFrames)")
                    isPlaceholderCaptureMode = true
                    receivingRemoteFrames = false
                    remoteFrameBridge.setPlaceholderCaptureActive(true)
                    startPlaceholderDisplayLink()
                }
            } else {
                exitPiPPlaceholderCaptureModeIfNeeded()
            }
        case .remoteVideoUnavailable(let userId):
            let participant = dataSource.participant(for: userId)
            let isOnlyParticipant = !hasActiveRemoteParticipant

            guard let participant = participant else {
                if isOnlyParticipant {
                    showOnlyPersonPlaceholder(placeholderView)
                } else {
                    preparePlaceholderLayout(placeholderView)
                    let speakingState = speakingState(for: userId)
                    placeholderView.configure(userId: userId, displayName: nil, speakingState: speakingState)
                    placeholderView.layoutIfNeeded()
                    onPiPPlaceholderUnderlayVisible?(true)
                    if !isPlaceholderCaptureMode {
                        pipLogInfo("System PiP: placeholder capture (participant unresolved) userId=\(userId)")
                        isPlaceholderCaptureMode = true
                        receivingRemoteFrames = false
                        remoteVideoInactiveFromBlackFrames = false
                        remoteFrameBridge.setPlaceholderCaptureActive(true)
                        startPlaceholderDisplayLink()
                    }
                }
                return
            }

            preparePlaceholderLayout(placeholderView)
            let speakingState = speakingState(for: userId)
            placeholderView.configure(participant: participant, speakingState: speakingState)
            placeholderView.layoutIfNeeded()
            onPiPPlaceholderUnderlayVisible?(true)
            if !isPlaceholderCaptureMode {
                pipLogInfo("System PiP: placeholder capture (no remote camera object) userId=\(userId)")
                isPlaceholderCaptureMode = true
                receivingRemoteFrames = false
                remoteVideoInactiveFromBlackFrames = false
                remoteFrameBridge.setPlaceholderCaptureActive(true)
                startPlaceholderDisplayLink()
            }

        case .none:
            if !hasActiveRemoteParticipant {
                showOnlyPersonPlaceholder(placeholderView)
                return
            }
            // Prefer any remote participant for a stable placeholder while focus is resolving.
            let rows = dataSource.remoteCameraSnapshot()
            if let row = rows.first(where: { !$0.participant.isLocal() }) {
                preparePlaceholderLayout(placeholderView)
                let speakingState = speakingState(for: (row.participant.getId() ?? ""))
                placeholderView.configure(participant: row.participant, speakingState: speakingState)
                placeholderView.layoutIfNeeded()
                onPiPPlaceholderUnderlayVisible?(true)
                if !isPlaceholderCaptureMode {
                    pipLogInfo("System PiP: placeholder capture (no focus source, remote participant fallback) userId=\((row.participant.getId() ?? ""))")
                    isPlaceholderCaptureMode = true
                    receivingRemoteFrames = false
                    remoteVideoInactiveFromBlackFrames = false
                    remoteFrameBridge.setPlaceholderCaptureActive(true)
                    startPlaceholderDisplayLink()
                }
                return
            }
            exitPiPPlaceholderCaptureModeIfNeeded()

        default:
            exitPiPPlaceholderCaptureModeIfNeeded()
        }
    }


    private func exitPiPPlaceholderCaptureModeIfNeeded() {
        guard isPlaceholderCaptureMode else { return }
        isPlaceholderCaptureMode = false
        receivingRemoteFrames = false
        remoteVideoInactiveFromBlackFrames = false
        nextPlaceholderPresentationTicks = 0
        stopPlaceholderDisplayLinkIfNeeded()
        remoteFrameBridge.setPlaceholderCaptureActive(false)
        pipPlaceholderView?.invalidateRenderedInitialsCache()
        onPiPPlaceholderUnderlayVisible?(false)
    }


    private func captureFrame() {
        let captureStartTs = CACurrentMediaTime()
        applyAdaptivePiPFrameRatePolicyIfNeeded()

        if !isPlaceholderCaptureMode && receivingRemoteFrames {
            return
        }
        if !isPlaceholderCaptureMode {
            remoteFrameBridge.attachIfNeeded()
        }

        var viewForCapture: UIView?
        var captureBounds = CGRect.zero
        var usePlaceholderRasterBlit = false
        /// Exact `rasterFullFrameBitmap()` from main; rendered with the same Y-flip contract as `layer.render(in:)`.
        var placeholderRasterUIImage: UIImage?
        var mainThreadSnapshotCGImage: CGImage?
        DispatchQueue.main.sync { [weak self] in
            guard let self = self else { return }
            if self.isPlaceholderCaptureMode, let placeholder = self.pipPlaceholderView {
                placeholder.layoutIfNeeded()
                var bounds = placeholder.bounds.integral
                if bounds.width < 2 || bounds.height < 2 {
                    placeholder.bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
                    placeholder.layoutIfNeeded()
                    bounds = placeholder.bounds.integral
                }
                viewForCapture = placeholder
                let supersampledSize = CGSize(width: bounds.width * self.placeholderSupersampleScale,
                                              height: bounds.height * self.placeholderSupersampleScale)
                captureBounds = CGRect(origin: .zero, size: supersampledSize).integral
                usePlaceholderRasterBlit = true
                placeholderRasterUIImage = placeholder.rasterFullFrameBitmap(targetSize: supersampledSize)
                self.placeholderRasterFrameCount += 1
            } else if let source = self.sourceView {
                viewForCapture = source
                captureBounds = source.bounds.integral
                usePlaceholderRasterBlit = false
                if self.enableMainThreadSnapshotOptimization,
                   captureBounds.width > 0,
                   captureBounds.height > 0 {
                    let renderer = UIGraphicsImageRenderer(size: captureBounds.size)
                    mainThreadSnapshotCGImage = renderer.image { context in
                        source.layer.render(in: context.cgContext)
                    }.cgImage
                }
            }
        }

        guard let viewForCapture = viewForCapture else {
            return
        }
        guard captureBounds.width > 0, captureBounds.height > 0 else {
            return
        }

        let width = Int(captureBounds.width)
        let height = Int(captureBounds.height)

        if !isPoolCompatible(width: width, height: height) {
            recreatePool(width: width, height: height)
        }

        guard let pool = pixelBufferPool else {
            return
        }
        var pixelBuffer: CVPixelBuffer?
        let createResult = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard createResult == kCVReturnSuccess, let unwrappedPixelBuffer = pixelBuffer else {
            return
        }

        CVPixelBufferLockBaseAddress(unwrappedPixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(unwrappedPixelBuffer) else {
            return
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(unwrappedPixelBuffer)
        guard let context = CGContext(data: baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: Self.captureDeviceRGBColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        if usePlaceholderRasterBlit {
            let blitRect = CGRect(x: 0, y: 0, width: width, height: height)
            if let bmp = placeholderRasterUIImage {
                UIGraphicsPushContext(context)
                bmp.draw(in: blitRect)
                UIGraphicsPopContext()
            } else {
                context.setFillColor(UIColor.black.cgColor)
                context.fill(blitRect)
            }
        } else {
            if let snapshot = mainThreadSnapshotCGImage {
                context.draw(snapshot, in: CGRect(x: 0, y: 0, width: width, height: height))
            } else {
                DispatchQueue.main.sync {
                    viewForCapture.layer.render(in: context)
                }
            }
        }

        if formatDescription == nil {
            var description: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: unwrappedPixelBuffer, formatDescriptionOut: &description)
            formatDescription = description
        }

        guard let formatDescription = formatDescription else {
            return
        }

        let pts = CMTime(value: nextPlaceholderPresentationTicks, timescale: placeholderPresentationTimescale)
        nextPlaceholderPresentationTicks += placeholderTicksPerFrame
        let frameDuration = CMTime(value: placeholderTicksPerFrame, timescale: placeholderPresentationTimescale)
        var timing = CMSampleTimingInfo(duration: frameDuration,
                                        presentationTimeStamp: pts,
                                        decodeTimeStamp: CMTime.invalid)

        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                              imageBuffer: unwrappedPixelBuffer,
                                                              formatDescription: formatDescription,
                                                              sampleTiming: &timing,
                                                              sampleBufferOut: &sampleBuffer)
        guard status == noErr, let readySampleBuffer = sampleBuffer else {
            return
        }
        if isPlaceholderCaptureMode,
           let attachments = CMSampleBufferGetSampleAttachmentsArray(readySampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        captureFrameCount += 1
        captureFrameTimeAccumMs += max(0, (CACurrentMediaTime() - captureStartTs) * 1000)
        logCapturePerfIfNeeded()
        emit(sampleBuffer: readySampleBuffer)
    }

    private func logCapturePerfIfNeeded() {
        let now = CACurrentMediaTime()
        guard now - lastCapturePerfLogTs >= 5.0 else { return }
        lastCapturePerfLogTs = now
        let avgCaptureMs = captureFrameCount > 0 ? captureFrameTimeAccumMs / Double(captureFrameCount) : 0
        pipLogInfo("System PiP capture metrics: frames=\(captureFrameCount) avgCaptureMs=\(String(format: "%.2f", avgCaptureMs)) placeholderRasterFrames=\(placeholderRasterFrameCount) placeholderMode=\(isPlaceholderCaptureMode)")
        captureFrameCount = 0
        captureFrameTimeAccumMs = 0
        placeholderRasterFrameCount = 0
    }

    private func emit(sampleBuffer: CMSampleBuffer) {
        guard isCapturing else { return }
        if !hasProducedFirstSample {
            hasProducedFirstSample = true
            onFirstSample?()
        }
        onSampleBuffer?(sampleBuffer)
    }

    private func recreatePool(width: Int, height: Int) {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var newPool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &newPool)
        pixelBufferPool = newPool
        formatDescription = nil
    }

    private func isPoolCompatible(width: Int, height: Int) -> Bool {
        guard let pool = pixelBufferPool else { return false }
        let attributes = CVPixelBufferPoolGetPixelBufferAttributes(pool) as? [String: Any]
        let currentWidth = attributes?[kCVPixelBufferWidthKey as String] as? Int
        let currentHeight = attributes?[kCVPixelBufferHeightKey as String] as? Int
        return currentWidth == width && currentHeight == height
    }
}

/// Registers `registerFrameEventListener` on the focused remote camera or share and
/// converts each `VCVideoFrame` (I420) into an NV12 `CMSampleBuffer` for the display layer.
@available(iOS 15.0, *)
fileprivate final class RemoteCameraSampleBufferBridge: NSObject {

    weak var dataSource: PiPCallDataSource?

    private enum ActiveAttachment {
        case none
        case camera(VCRemoteCamera)
        case share(VCRemoteWindowShare)
    }

    private var attachment = ActiveAttachment.none
    private var formatDescription: CMVideoFormatDescription?
    private var sampleHandler: ((CMSampleBuffer) -> Void)?
    private var didLogFirstFrame = false
    private var receivedFrameCount: Int64 = 0
    private var convertedFrameCount: Int64 = 0
    private var lastFrameWidth: Int = 0
    private var lastFrameHeight: Int = 0
    /// Strictly increasing presentation timeline (reset when capture source changes). `AVSampleBufferDisplayLayer` requires monotonic PTS.
    private var nextPresentationTicks: Int64 = 0
    private let presentationTimescale: Int32 = 60_000
    /// 2000 ticks @ 60kHz = 1/30 s per frame (matches typical remote video cadence).
    private let ticksPerFrame: Int64 = 2_000
    private var pixelBufferPool: CVPixelBufferPool?
    private var pooledFrameWidth: Int = 0
    private var pooledFrameHeight: Int = 0
    private var targetFrameInterval: CFTimeInterval = 1.0 / 12.0
    private var lastEmittedFrameTs: CFTimeInterval = 0
    private var droppedByRateLimitCount: Int64 = 0
    private var droppedByConversionCount: Int64 = 0
    private var conversionTimeAccumMs: Double = 0
    private var conversionSamples: Int64 = 0
    private var lastPerfLogTs: CFTimeInterval = CACurrentMediaTime()

    private let queue = DispatchQueue(label: "com.vidyo.systempip.remote-camera-bridge", qos: .userInitiated)
    private var frameWatchdogTimer: DispatchSourceTimer?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var sessionId: Int = 0
    /// PiP target is a participant with no `VCRemoteCamera` (SDK removed it); avoid attaching an unrelated camera as fallback.
    private var suppressFallbackCameraAttach = false

    /// Called when frames stall so `PiPFocusTracker` can re-resolve the active source.
    var stallRecoveryHandler: (() -> Void)?
    /// Clear stale PiP pixels when the capture source changes (share handoff, camera switch, stall).
    var onAttachmentRequiresDisplayFlush: (() -> Void)?
    /// Invoked on main ~1 Hz from the frame watchdog for `AVSampleBufferDisplayLayer` health checks.
    var onPeriodicDisplayLayerHealthCheck: (() -> Void)?
    /// Invoked on main when sustained black / real video returns (SDK often omits paused for remote camera).
    var onRemoteVideoLikelyInactive: ((Bool) -> Void)?
    /// One-shot log when the first frame arrives after a focus/attachment change.
    private var pendingLogFirstFrameAfterAttachmentChange = false
    /// One-shot per attachment: dump SDK plane geometry for diagnostics.
    private var didLogPlaneGeometry = false
    /// Avoid spamming logs when frames have odd width/height (invalid for NV12).
    private var didLogOddFrameDimensions = false
    /// When true, PiP shows a rasterized placeholder instead of remote frames; do not push camera frames to PiP, but keep frame listener when possible for black-frame inference.
    private var isPlaceholderCaptureActive = false
    private var consecutiveBlackFrames = 0
    private var consecutiveNonBlackFrames = 0
    private var lastReportedBlackInactive: Bool?
    /// Guard repeated "no frame yet" inactive notifications from watchdog.
    private var didReportNoFrameInactive = false

    private func resetBlackFrameHeuristic() {
        let wasInactive = lastReportedBlackInactive == true
        consecutiveBlackFrames = 0
        consecutiveNonBlackFrames = 0
        lastReportedBlackInactive = nil
        didReportNoFrameInactive = false
        if wasInactive {
            DispatchQueue.main.async { [weak self] in
                self?.onRemoteVideoLikelyInactive?(false)
            }
        }
    }

    private func isVideoFrameYBlackish(_ videoFrame: VCVideoFrame) -> Bool {
        let w = Int(videoFrame.getWidthY())
        let h = Int(videoFrame.getHeightY())
        guard w >= 16, h >= 16, let yHead = videoFrame.getDataY() else { return false }
        let pitch = Int(videoFrame.getPitchY())
        let offset = Int(videoFrame.getOffsetY())
        let base = yHead.advanced(by: offset)
        var sum: Int64 = 0
        var maxLuma: UInt8 = 0
        let stepX = max(1, w / 32)
        let stepY = max(1, h / 32)
        var count = 0
        for row in stride(from: 0, to: h, by: stepY) {
            let rowPtr = base.advanced(by: row * pitch)
            for col in stride(from: 0, to: w, by: stepX) {
                let v = rowPtr[col]
                sum += Int64(v)
                if v > maxLuma { maxLuma = v }
                count += 1
            }
        }
        let avg = sum / Int64(max(count, 1))
        return avg < 10 && maxLuma < 22
    }

    /// Runs for the focused camera even while placeholder capture is active so we can flip `blackInactive` when real video returns.
    private func updateBlackFrameHeuristic(isBlack: Bool) {
        guard case .camera = attachment else { return }
        if isBlack {
            consecutiveNonBlackFrames = 0
            consecutiveBlackFrames += 1
            if consecutiveBlackFrames >= 10, lastReportedBlackInactive != true {
                lastReportedBlackInactive = true
                DispatchQueue.main.async { [weak self] in
                    self?.onRemoteVideoLikelyInactive?(true)
                }
            }
        } else {
            consecutiveBlackFrames = 0
            consecutiveNonBlackFrames += 1
            if consecutiveNonBlackFrames >= 3, lastReportedBlackInactive != false {
                lastReportedBlackInactive = false
                DispatchQueue.main.async { [weak self] in
                    self?.onRemoteVideoLikelyInactive?(false)
                }
            }
        }
    }

    private func resetPresentationTimeline() {
        nextPresentationTicks = 0
    }

    func setTargetFrameRate(_ fps: Int) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let clamped = max(1, fps)
            self.targetFrameInterval = 1.0 / Double(clamped)
        }
    }

    private func shouldRateLimitCurrentFrame() -> Bool {
        let now = CACurrentMediaTime()
        if lastEmittedFrameTs > 0, now - lastEmittedFrameTs < targetFrameInterval {
            droppedByRateLimitCount += 1
            logPerfIfNeeded()
            return true
        }
        lastEmittedFrameTs = now
        return false
    }

    private func ensurePixelBufferPool(width: Int, height: Int) -> CVPixelBufferPool? {
        if let pool = pixelBufferPool, pooledFrameWidth == width, pooledFrameHeight == height {
            return pool
        }
        let videoRangeFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(videoRangeFormat),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        var newPool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &newPool)
        pixelBufferPool = newPool
        pooledFrameWidth = width
        pooledFrameHeight = height
        formatDescription = nil
        return newPool
    }

    private func logPerfIfNeeded() {
        let now = CACurrentMediaTime()
        guard now - lastPerfLogTs >= 5.0 else { return }
        lastPerfLogTs = now
        let avgConversionMs = conversionSamples > 0 ? conversionTimeAccumMs / Double(conversionSamples) : 0
        pipLogInfo("System PiP remote bridge metrics: received=\(receivedFrameCount) converted=\(convertedFrameCount) droppedRateLimit=\(droppedByRateLimitCount) droppedConversion=\(droppedByConversionCount) avgConvertMs=\(String(format: "%.2f", avgConversionMs))")
        conversionTimeAccumMs = 0
        conversionSamples = 0
    }

    func setPlaceholderCaptureActive(_ active: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.isPlaceholderCaptureActive != active else { return }
            self.isPlaceholderCaptureActive = active
            if active {
                // Do not clearAttachment(): we must keep receiving camera frames for black→real detection while PiP shows initials.
                self.formatDescription = nil
                self.lastFrameWidth = 0
                self.lastFrameHeight = 0
                self.didLogFirstFrame = false
                self.didLogPlaneGeometry = false
                self.didLogOddFrameDimensions = false
                self.resetPresentationTimeline()
                DispatchQueue.main.async { [weak self] in
                    self?.onAttachmentRequiresDisplayFlush?()
                }
            } else {
                self.resetBlackFrameHeuristic()
                DispatchQueue.main.async { [weak self] in
                    self?.stallRecoveryHandler?()
                }
            }
        }
    }

    func applyFocusTarget(_ target: PiPFocusTarget, force: Bool = false, completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?() }
                return
            }
            self.applyFocusTargetLocked(target, force: force)
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    func start(sampleHandler: @escaping (CMSampleBuffer) -> Void) {
        sessionId += 1
        let currentSessionId = sessionId
        self.sampleHandler = sampleHandler
        didLogFirstFrame = false
        didLogPlaneGeometry = false
        didLogOddFrameDimensions = false
        receivedFrameCount = 0
        convertedFrameCount = 0
        droppedByRateLimitCount = 0
        droppedByConversionCount = 0
        conversionTimeAccumMs = 0
        conversionSamples = 0
        lastPerfLogTs = CACurrentMediaTime()
        lastFrameTimestamp = CACurrentMediaTime()
        queue.async { [weak self] in
            guard let self = self, self.sessionId == currentSessionId else { return }
            self.suppressFallbackCameraAttach = false
            self.clearAttachment()
            self.pixelBufferPool = nil
            self.pooledFrameWidth = 0
            self.pooledFrameHeight = 0
            self.formatDescription = nil
            self.lastFrameWidth = 0
            self.lastFrameHeight = 0
            self.didLogPlaneGeometry = false
            self.didLogOddFrameDimensions = false
            self.lastEmittedFrameTs = 0
            self.resetPresentationTimeline()
            self.startFrameWatchdog()
        }
    }

    func attachIfNeeded() {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.suppressFallbackCameraAttach else {
                return
            }
            self.attachFallbackFirstCameraIfNeeded()
        }
    }

    func stop() {
        sessionId += 1
        let currentSessionId = sessionId
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.sessionId == currentSessionId else { return }
            self.stopFrameWatchdog()
            self.suppressFallbackCameraAttach = false
            self.clearAttachment()
            self.isPlaceholderCaptureActive = false
            self.pixelBufferPool = nil
            self.pooledFrameWidth = 0
            self.pooledFrameHeight = 0
            self.formatDescription = nil
            self.lastFrameWidth = 0
            self.lastFrameHeight = 0
            self.didLogPlaneGeometry = false
            self.didLogOddFrameDimensions = false
            self.lastEmittedFrameTs = 0
            self.resetPresentationTimeline()
            self.sampleHandler = nil
        }
    }

    private func startFrameWatchdog() {
        stopFrameWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            self?.handleFrameWatchdogTick()
        }
        frameWatchdogTimer = timer
        timer.resume()
    }

    private func stopFrameWatchdog() {
        frameWatchdogTimer?.cancel()
        frameWatchdogTimer = nil
    }

    private func handleFrameWatchdogTick() {
        DispatchQueue.main.async { [weak self] in
            self?.onPeriodicDisplayLayerHealthCheck?()
        }
        switch attachment {
        case .none:
            if isPlaceholderCaptureActive {
                return
            }
            if suppressFallbackCameraAttach {
                return
            }
            attachFallbackFirstCameraIfNeeded()
            return
        default:
            break
        }
        let elapsed = CACurrentMediaTime() - lastFrameTimestamp
        if elapsed > 1.2 {
            if case .share = attachment {
                // Keep the last share frame visible during brief share stalls.
                // Clearing/flushing here causes black PiP flashes before share resumes.
                pipLogWarning("System PiP remote bridge watchdog: share frame stall \(elapsed)s, requesting soft focus recovery (no flush)")
                lastFrameTimestamp = CACurrentMediaTime()
                DispatchQueue.main.async { [weak self] in
                    self?.stallRecoveryHandler?()
                }
                return
            }

            if case .camera = attachment {
                // Initial PiP open can focus a remote camera row that never produces frames when video is off.
                // Promote placeholder mode quickly instead of showing black until an on→off transition happens.
                pipLogWarning("System PiP remote bridge watchdog: camera frame stall \(elapsed)s, marking inactive and requesting soft focus recovery")
                lastFrameTimestamp = CACurrentMediaTime()
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if !self.didReportNoFrameInactive {
                        self.didReportNoFrameInactive = true
                        self.onRemoteVideoLikelyInactive?(true)
                    }
                    self.stallRecoveryHandler?()
                }
                return
            }

            pipLogWarning("System PiP remote bridge watchdog: frame stall \(elapsed)s, requesting focus recovery")
            clearAttachment()
            formatDescription = nil
            lastFrameWidth = 0
            lastFrameHeight = 0
            didLogFirstFrame = false
            didLogPlaneGeometry = false
            didLogOddFrameDimensions = false
            lastFrameTimestamp = CACurrentMediaTime()
            resetPresentationTimeline()
            DispatchQueue.main.async { [weak self] in
                self?.onAttachmentRequiresDisplayFlush?()
                self?.stallRecoveryHandler?()
            }
        }
    }

    private func attachFallbackFirstCameraIfNeeded() {
        guard !isPlaceholderCaptureActive else { return }
        guard !suppressFallbackCameraAttach else { return }
        guard case .none = attachment else { return }
        let cameras = dataSource?.remoteCameraSnapshot() ?? []
        guard let first = cameras.first else {
            pipLogInfo("System PiP remote frame bridge: no remote camera yet, using fallback capture")
            return
        }
        attachment = .camera(first.camera)
        _ = first.camera.registerFrameEventListener(self)
        didLogFirstFrame = false
        didLogPlaneGeometry = false
        didLogOddFrameDimensions = false
        pendingLogFirstFrameAfterAttachmentChange = true
        lastFrameTimestamp = CACurrentMediaTime()
        resetPresentationTimeline()
        pipLogInfo("System PiP remote frame bridge: fallback attach camera \(first.camera.getId() ?? "unknown")")
        DispatchQueue.main.async { [weak self] in
            self?.onAttachmentRequiresDisplayFlush?()
        }
    }


    /// SDK can rotate share wrapper instances while the same share stream is active.
    /// Prefer stable share id comparison to avoid redundant detach/attach black flashes.
    private func isSameLogicalShare(_ lhs: VCRemoteWindowShare, _ rhs: VCRemoteWindowShare) -> Bool {
        if lhs === rhs { return true }
        let lhsId = lhs.getId() ?? ""
        let rhsId = rhs.getId() ?? ""
        if !lhsId.isEmpty && !rhsId.isEmpty {
            return lhsId == rhsId
        }
        return false
    }

    private func applyFocusTargetLocked(_ target: PiPFocusTarget, force: Bool) {
        switch target {
        case .none:
            suppressFallbackCameraAttach = false
            clearAttachment()
            resetPresentationTimeline()
            lastEmittedFrameTs = 0
            attachFallbackFirstCameraIfNeeded()
            if case .none = attachment {
                DispatchQueue.main.async { [weak self] in
                    self?.onAttachmentRequiresDisplayFlush?()
                }
            }
        case .camera(let camera):
            suppressFallbackCameraAttach = false
            if !force {
                if case .camera(let existing) = attachment, existing === camera { return }
            }
            clearAttachment()
            attachment = .camera(camera)
            formatDescription = nil
            lastFrameWidth = 0
            lastFrameHeight = 0
            didLogFirstFrame = false
            didLogPlaneGeometry = false
            didLogOddFrameDimensions = false
            lastFrameTimestamp = CACurrentMediaTime()
            resetPresentationTimeline()
            lastEmittedFrameTs = 0
            _ = camera.registerFrameEventListener(self)
            pendingLogFirstFrameAfterAttachmentChange = true
            pipLogInfo("System PiP remote frame bridge: focus camera \(camera.getId() ?? "unknown")")
            DispatchQueue.main.async { [weak self] in
                self?.onAttachmentRequiresDisplayFlush?()
            }
        case .share(let share):
            suppressFallbackCameraAttach = false
            if !force {
                if case .share(let existing) = attachment, isSameLogicalShare(existing, share) { return }
            }
            clearAttachment()
            attachment = .share(share)
            formatDescription = nil
            lastFrameWidth = 0
            lastFrameHeight = 0
            didLogFirstFrame = false
            didLogPlaneGeometry = false
            didLogOddFrameDimensions = false
            lastFrameTimestamp = CACurrentMediaTime()
            resetPresentationTimeline()
            lastEmittedFrameTs = 0
            _ = share.registerFrameEventListener(self)
            pendingLogFirstFrameAfterAttachmentChange = true
            pipLogInfo("System PiP remote frame bridge: focus share \(share.getId() ?? "unknown")")
            // Do not force-flush when switching camera -> share.
            // Keeping the last good frame prevents transient black PiP while the first share frame arrives.
        case .remoteVideoUnavailable(let userId):
            suppressFallbackCameraAttach = true
            clearAttachment()
            formatDescription = nil
            lastFrameWidth = 0
            lastFrameHeight = 0
            didLogFirstFrame = false
            didLogPlaneGeometry = false
            didLogOddFrameDimensions = false
            lastFrameTimestamp = CACurrentMediaTime()
            resetPresentationTimeline()
            lastEmittedFrameTs = 0
            pipLogInfo("System PiP remote frame bridge: focus remoteVideoUnavailable userId=\(userId)")
            DispatchQueue.main.async { [weak self] in
                self?.onAttachmentRequiresDisplayFlush?()
            }
        }
    }

    private func clearAttachment() {
        switch attachment {
        case .camera(let cam):
            cam.unregisterFrameEventListener()
        case .share(let sh):
            sh.unregisterFrameEventListener()
        case .none:
            break
        }
        attachment = .none
        resetBlackFrameHeuristic()
    }

    private func makeSampleBuffer(from videoFrame: VCVideoFrame) -> CMSampleBuffer? {
        let conversionStartTs = CACurrentMediaTime()
        let rawWidth = Int(videoFrame.getWidth())
        let rawHeight = Int(videoFrame.getHeight())
        guard rawWidth > 0, rawHeight > 0 else { return nil }
        // NV12 requires even dimensions. For odd share sizes, crop one pixel to avoid dropping frames.
        let width = rawWidth & ~1
        let height = rawHeight & ~1
        guard width > 0, height > 0 else { return nil }
        if (width != rawWidth || height != rawHeight) && !didLogOddFrameDimensions {
            didLogOddFrameDimensions = true
            pipLogWarning("System PiP: received odd-sized frame \(rawWidth)x\(rawHeight), cropping to even \(width)x\(height) for NV12")
        }

        if width != lastFrameWidth || height != lastFrameHeight {
            formatDescription = nil
            lastFrameWidth = width
            lastFrameHeight = height
            pixelBufferPool = nil
            pooledFrameWidth = 0
            pooledFrameHeight = 0
        }

        var pixelBuffer: CVPixelBuffer?
        guard let pool = ensurePixelBufferPool(width: width, height: height) else {
            droppedByConversionCount += 1
            logPerfIfNeeded()
            return nil
        }
        let pixelStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard pixelStatus == kCVReturnSuccess, let pixelBuffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let srcYHead = videoFrame.getDataY(),
              let srcCbHead = videoFrame.getDataCb(),
              let srcCrHead = videoFrame.getDataCr(),
              let dstY = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let dstUV = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            return nil
        }

        let srcYPitch = Int(videoFrame.getPitchY())
        let srcCbPitch = Int(videoFrame.getPitchCb())
        let srcCrPitch = Int(videoFrame.getPitchCr())
        let dstYPitch = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let dstUVPitch = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

        let yPlaneHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let uvPlaneHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        memset(dstY, 0, dstYPitch * yPlaneHeight)
        memset(dstUV, 0x80, dstUVPitch * uvPlaneHeight)

        let srcYW = Int(videoFrame.getWidthY())
        let srcYH = Int(videoFrame.getHeightY())
        let srcYOff = Int(videoFrame.getOffsetY())
        let srcCbW = Int(videoFrame.getWidthCb())
        let srcCbH = Int(videoFrame.getHeightCb())
        let srcCbOff = Int(videoFrame.getOffsetCb())
        let srcCrW = Int(videoFrame.getWidthCr())
        let srcCrH = Int(videoFrame.getHeightCr())
        let srcCrOff = Int(videoFrame.getOffsetCr())

        let srcYBase = srcYHead.advanced(by: srcYOff)
        let srcCbBase = srcCbHead.advanced(by: srcCbOff)
        let srcCrBase = srcCrHead.advanced(by: srcCrOff)

        if !didLogPlaneGeometry {
            didLogPlaneGeometry = true
            pipLogInfo("System PiP plane geometry: frame=\(width)x\(height), Y=\(srcYW)x\(srcYH) off=\(srcYOff) pitch=\(srcYPitch), Cb=\(srcCbW)x\(srcCbH) off=\(srcCbOff) pitch=\(srcCbPitch), Cr=\(srcCrW)x\(srcCrH) off=\(srcCrOff) pitch=\(srcCrPitch), dstYPitch=\(dstYPitch) dstUVPitch=\(dstUVPitch)")
        }

        let yRows = min(srcYH, height)
        let yRowBytes = min(width, srcYW, dstYPitch)
        guard yRows > 0, yRowBytes > 0 else { return nil }

        for row in 0..<yRows {
            memcpy(dstY.advanced(by: row * dstYPitch),
                   srcYBase.advanced(by: row * srcYPitch),
                   yRowBytes)
        }

        let chromaRows = min(srcCbH, srcCrH, height / 2)
        let chromaCols = min(srcCbW, srcCrW, width / 2)
        guard chromaRows > 0, chromaCols > 0 else { return nil }

        for row in 0..<chromaRows {
            let cbRow = srcCbBase.advanced(by: row * srcCbPitch)
            let crRow = srcCrBase.advanced(by: row * srcCrPitch)
            let uvRow = dstUV.advanced(by: row * dstUVPitch).assumingMemoryBound(to: UInt8.self)
            for col in 0..<chromaCols {
                uvRow[col * 2] = cbRow[col]
                uvRow[col * 2 + 1] = crRow[col]
            }
        }

        if formatDescription == nil {
            var description: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &description)
            formatDescription = description
        }

        guard let formatDescription = formatDescription else { return nil }

        let pts = CMTime(value: nextPresentationTicks, timescale: presentationTimescale)
        nextPresentationTicks += ticksPerFrame
        let frameDuration = CMTime(value: ticksPerFrame, timescale: presentationTimescale)
        var timing = CMSampleTimingInfo(duration: frameDuration,
                                        presentationTimeStamp: pts,
                                        decodeTimeStamp: CMTime.invalid)
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                                    imageBuffer: pixelBuffer,
                                                                    formatDescription: formatDescription,
                                                                    sampleTiming: &timing,
                                                                    sampleBufferOut: &sampleBuffer)
        guard sampleStatus == noErr, let sampleBuffer = sampleBuffer else { return nil }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }

        convertedFrameCount += 1
        conversionSamples += 1
        conversionTimeAccumMs += max(0, (CACurrentMediaTime() - conversionStartTs) * 1000)
        if convertedFrameCount % 60 == 0 {
            pipLogInfo("System PiP remote bridge cadence: \(receivedFrameCount) received, \(convertedFrameCount) converted, ptsTicks=\(pts.value)/\(pts.timescale), main=\(Thread.isMainThread), queue=com.vidyo.systempip.remote-camera-bridge")
        }
        logPerfIfNeeded()
        return sampleBuffer
    }
}

@available(iOS 15.0, *)
extension RemoteCameraSampleBufferBridge: VCRemoteCameraIRegisterFrameEventListener {
    func onRemoteCameraFrame(_ participant: VCParticipant!, videoFrame: VCVideoFrame!) {
        guard let videoFrame = videoFrame else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            self.didReportNoFrameInactive = false
            self.receivedFrameCount += 1
            self.lastFrameTimestamp = CACurrentMediaTime()

            let isBlack = self.isVideoFrameYBlackish(videoFrame)
            self.updateBlackFrameHeuristic(isBlack: isBlack)

            guard !self.isPlaceholderCaptureActive else {
                return
            }

            if self.shouldRateLimitCurrentFrame() {
                return
            }
            guard let sampleBuffer = self.makeSampleBuffer(from: videoFrame) else {
                self.droppedByConversionCount += 1
                self.logPerfIfNeeded()
                return
            }
            if self.pendingLogFirstFrameAfterAttachmentChange {
                self.pendingLogFirstFrameAfterAttachmentChange = false
                pipLogInfo("System PiP remote frame bridge: first frame after attachment change (camera) \(videoFrame.getWidth())x\(videoFrame.getHeight())")
            }
            if !self.didLogFirstFrame {
                self.didLogFirstFrame = true
                pipLogInfo("System PiP remote frame bridge: first camera frame \(videoFrame.getWidth())x\(videoFrame.getHeight())")
            }
            self.sampleHandler?(sampleBuffer)
        }
    }
}

@available(iOS 15.0, *)
extension RemoteCameraSampleBufferBridge: VCRemoteWindowShareIRegisterFrameEventListener {
    func onRemoteWindowShareFrame(_ participant: VCParticipant!, videoFrame: VCVideoFrame!) {
        guard let videoFrame = videoFrame else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            self.resetBlackFrameHeuristic()
            self.receivedFrameCount += 1
            self.lastFrameTimestamp = CACurrentMediaTime()
            if self.shouldRateLimitCurrentFrame() {
                return
            }
            guard let sampleBuffer = self.makeSampleBuffer(from: videoFrame) else {
                self.droppedByConversionCount += 1
                self.logPerfIfNeeded()
                return
            }
            if self.pendingLogFirstFrameAfterAttachmentChange {
                self.pendingLogFirstFrameAfterAttachmentChange = false
                pipLogInfo("System PiP remote frame bridge: first frame after attachment change (share) \(videoFrame.getWidth())x\(videoFrame.getHeight())")
            }
            if !self.didLogFirstFrame {
                self.didLogFirstFrame = true
                pipLogInfo("System PiP remote frame bridge: first share frame \(videoFrame.getWidth())x\(videoFrame.getHeight())")
            }
            self.sampleHandler?(sampleBuffer)
        }
    }
}
