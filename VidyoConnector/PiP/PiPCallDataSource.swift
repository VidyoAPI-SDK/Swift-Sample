//
//  PiPCallDataSource.swift
//  VidyoConnector
//
//  Bridges VidyoConnector call state into System Picture-in-Picture (`PiPManager`).
//
//  Why this file exists
//  --------------------
//  `PiPManager` must not depend on NeoIOS types. It only needs a small, stable surface of
//  call state (cameras, shares, pin, loudest, mic). This file defines that surface and the
//  sample adapter that reads it from `ConferenceViewController` + connector managers.
//
//  If you port PiP to another VCConnector app:
//  1. Keep the `PiPCallDataSource` protocol (and the row structs).
//  2. Replace `ConferencePiPDataSource` with an adapter for your own managers, or keep this
//     class and point `conference` at your call screen equivalent.
//
//  Important SDK constraint
//  ------------------------
//  `VCConnector` allows only one remote-camera event listener. PiP must share
//  `RemoteCameraManager`'s registration (snapshots + change observers), not register a
//  second listener.
//

import Foundation
import VidyoClientIOS

// MARK: - Snapshot rows used by PiP focus / frame binding

/// One remote camera currently known to the connector, for PiP focus selection.
struct PiPRemoteCameraRow {
    /// Live SDK camera object — used with `registerFrameEventListener` when this row is focused.
    let camera: VCRemoteCamera
    let participant: VCParticipant
    /// `true` when SDK reports paused/stopped/suspended/removed (show initials placeholder).
    let isPaused: Bool
}

/// One remote window share currently active, for PiP focus selection (highest priority).
struct PiPRemoteShareRow {
    /// Live SDK share object — used with `registerFrameEventListener` when this row is focused.
    let share: VCRemoteWindowShare
    let participant: VCParticipant
}

// MARK: - Protocol PiPManager reads

/// Call-state inputs required by `PiPManager` / `PiPFocusTracker`.
///
/// Implement this for any host app. The VidyoConnector sample provides
/// `ConferencePiPDataSource` below.
@available(iOS 15.0, *)
protocol PiPCallDataSource: AnyObject {
    /// Local participant user id — used to skip the local user's own share in PiP.
    var localUserId: String { get }
    /// Currently pinned participant id, or `nil` if none / pinning unsupported.
    var pinnedParticipantId: String? { get }
    /// Loudest remote speaker id from `onLoudestParticipantChanged`, or `nil`.
    var loudestParticipantId: String? { get }

    /// Thread-safe snapshot of remote cameras (objects must remain valid for frame listeners).
    func remoteCameraSnapshot() -> [PiPRemoteCameraRow]
    /// Thread-safe snapshot of remote window shares.
    func remoteShareSnapshot() -> [PiPRemoteShareRow]
    /// Look up a `VCParticipant` for placeholder name/initials.
    func participant(for userId: String) -> VCParticipant?
    /// `true` if at least one non-local participant is still in the call.
    func hasActiveRemoteParticipant() -> Bool
    /// Remote mic on/off for the speaking ring on the initials placeholder.
    func isRemoteMicOn(userId: String) -> Bool

    /// Subscribe to pin/camera/share/loudest/mic/participant changes. Returns an opaque token
    /// that must be passed to `removeFocusObserver`.
    func addFocusObserver(_ handler: @escaping () -> Void) -> AnyObject
    func removeFocusObserver(_ token: AnyObject)
}

// MARK: - Sample adapter

/// Maps this sample's `ConferenceViewController` + managers onto `PiPCallDataSource`.
///
/// Created by `ConferenceViewController.configureSystemPiPIfNeeded()` and released in
/// `tearDownSystemPiP()`.
@available(iOS 15.0, *)
final class ConferencePiPDataSource: PiPCallDataSource {
    /// Weak to avoid a retain cycle with the call screen that owns this adapter.
    weak var conference: ConferenceViewController?

    private let lock = NSLock()
    private var observers: [ObjectIdentifier: () -> Void] = [:]
    /// Tokens from manager `add*Observer` APIs — removed in `deinit`.
    private var managerTokens: [UUID] = []

    init(conference: ConferenceViewController) {
        self.conference = conference
        wireManagers()
    }

    deinit {
        tearDownManagerObservers()
    }

    // MARK: PiPCallDataSource

    var localUserId: String {
        let local = conference?.participantsManager.participants.first(where: { $0.isLocal() })
        return local?.getId() ?? ""
    }

    var pinnedParticipantId: String? {
        conference?.pinnedParticipantID
    }

    var loudestParticipantId: String? {
        conference?.participantsManager.loudestParticipantId
    }

    func remoteCameraSnapshot() -> [PiPRemoteCameraRow] {
        guard let manager = conference?.participantsManager.remoteCameraManager else { return [] }
        return manager.synchronizedSnapshot()
    }

    func remoteShareSnapshot() -> [PiPRemoteShareRow] {
        conference?.remoteShareManager.synchronizedSnapshot() ?? []
    }

    func participant(for userId: String) -> VCParticipant? {
        conference?.participantsManager.participants.first(where: { $0.getId() == userId })
    }

    func hasActiveRemoteParticipant() -> Bool {
        conference?.participantsManager.participants.contains(where: { !$0.isLocal() }) ?? false
    }

    func isRemoteMicOn(userId: String) -> Bool {
        conference?.participantsManager.remoteMicrophoneManager.isMicOn(for: userId) ?? false
    }

    func addFocusObserver(_ handler: @escaping () -> Void) -> AnyObject {
        let token = NSObject()
        lock.lock()
        observers[ObjectIdentifier(token)] = handler
        lock.unlock()
        return token
    }

    func removeFocusObserver(_ token: AnyObject) {
        lock.lock()
        observers.removeValue(forKey: ObjectIdentifier(token))
        lock.unlock()
    }

    /// Call from `ConferenceViewController.pinnedParticipantID.didSet` so PiP re-evaluates focus.
    func notePinnedChanged() {
        notifyFocusObservers()
    }

    // MARK: Private

    private func notifyFocusObservers() {
        lock.lock()
        let handlers = Array(observers.values)
        lock.unlock()
        DispatchQueue.main.async {
            handlers.forEach { $0() }
        }
    }

    /// Subscribe once to each manager that can change PiP focus or placeholder state.
    private func wireManagers() {
        guard let conference = conference else { return }
        let cameras = conference.participantsManager.remoteCameraManager
        let shares = conference.remoteShareManager
        let participants = conference.participantsManager
        let mics = conference.participantsManager.remoteMicrophoneManager

        managerTokens.append(cameras.addChangeObserver { [weak self] in self?.notifyFocusObservers() })
        managerTokens.append(shares.addChangeObserver { [weak self] in self?.notifyFocusObservers() })
        managerTokens.append(participants.addLoudestChangeObserver { [weak self] in self?.notifyFocusObservers() })
        managerTokens.append(participants.addParticipantsChangeObserver { [weak self] in self?.notifyFocusObservers() })
        managerTokens.append(mics.addChangeObserver { [weak self] in self?.notifyFocusObservers() })
    }

    private func tearDownManagerObservers() {
        guard let conference = conference else { return }
        let cameras = conference.participantsManager.remoteCameraManager
        let shares = conference.remoteShareManager
        let participants = conference.participantsManager
        let mics = conference.participantsManager.remoteMicrophoneManager
        for token in managerTokens {
            cameras.removeChangeObserver(token)
            shares.removeChangeObserver(token)
            participants.removeLoudestChangeObserver(token)
            participants.removeParticipantsChangeObserver(token)
            mics.removeChangeObserver(token)
        }
        managerTokens.removeAll()
    }
}
