//
//  ConferenceViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 26.05.2021.
//

import UIKit
import VidyoClientIOS

class ConferenceViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var connectionControlLabel: UILabel!
    @IBOutlet weak var lobbyViewContainer: UIView!
    @IBOutlet weak var toolbarContainer: UIView!
    @IBOutlet weak var cameraControlContainer: UIView!
    @IBOutlet weak var shareScreenLabelContainer: UIView!
    
    // MARK: - Const & vars
    let renderer = RendererManager.shared
    let loadingVC = LoadingViewController()
    let toolbar = ConferenceToolbar.loadFromNib()
    let cameraPtz = CameraControlView.loadFromNib()
    let lobbyInfo = LobbyInfoView.loadFromNib()
    
    var connectParams: ConnectionData?
    var pinnedParticipantID: String? {
        didSet {
            // System PiP: pin changes must refresh focus (share > pin > loudest > first camera).
            if #available(iOS 15.0, *) {
                pipDataSource?.notePinnedChanged()
            }
        }
    }
    
    var connector = ConnectorManager.shared
    var preferences = PreferencesManager.shared
    var connectionManager = ConnectorManager.shared.connectionManager
    var participantsManager = ConnectorManager.shared.participantManager
    var remoteShareManager = RemoteShareManager()
    var moderationManager = ModerationManager()
    // MARK: System PiP (see PiP/PiPManager.swift + PiP/PiPCallDataSource.swift)
    /// Owns AVKit PiP for this call screen (auto-starts on scene deactivate; no toolbar button).
    private var pipManager: PiPManager?
    /// Maps this VC + managers onto `PiPCallDataSource` for focus selection.
    private var pipDataSource: ConferencePiPDataSource?
    /// When true, ignore background auto-start (end-call / disconnect teardown in progress).
    var blockSystemPiPBackgroundStart = false
    
    var isLobbyMode: Bool = false {
        didSet {
            lobbyInfo.isLobbyMode = isLobbyMode
        }
    }
    var isBroadcastStarted: Bool = false {
        didSet {
            onScreenShareStateUpdated()
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareUI()
        prepareChatManager()
        prepareConnectionHandlers()
        prepareAutoReconnectHandlers()
        prepareModerationHandlers()
        prepareConferenceModeHandlers()
        videoView.isMultipleTouchEnabled = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateToolbarBadges()
        SettingsManager.shared.setDelegate(toolbar)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addObservers()
        // Keep remote camera/mic listeners for the whole conference (PiP shares the single camera listener).
        participantsManager.registerRemoteDevices()
        refreshVideoView()
        connectToRoomIfNeeded()
        configureSystemPiPIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideVideoView()
        // Invalidate PiP so no bubble survives leaving the call screen.
        tearDownSystemPiP()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.renderer.setViewSize(&self.videoView, self.videoView.frame)
        }
    }
    
    
    // MARK: - Functions
    @objc private func onBroadcastStarted() {
        isBroadcastStarted = true
    }
    
    @objc private func onBroadcastFinished() {
        isBroadcastStarted = false
    }
    
    @objc private func onNoRemoteCameraToControl() {
        log.info("No remote camera to control")
        hideCameraControlView()
    }
    
    @objc private func onBackgroundChose() {
        DispatchQueue.main.async {
            self.toolbar.updateBackgroundButton()
        }
        refreshVideoView()
    }
    
    private func onScreenShareStateUpdated() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.shareScreenLabelContainer.isHidden = !self.isBroadcastStarted
            self.toolbar.updateShareScreenButtonImage(forValue: self.isBroadcastStarted)
            guard self.isBroadcastStarted else { return }
            self.videoView.bringSubviewToFront(self.shareScreenLabelContainer)
        }
    }
    
    private func addObservers() {
        shareServices.addConferenceObservers()
        observe(.conferenceBroadcastStarted, #selector(onBroadcastStarted))
        observe(.conferenceBroadcastFinished, #selector(onBroadcastFinished))
        observe(.noRemoteCameraToControl, #selector(onNoRemoteCameraToControl))
        observe(.onBackgroundChose, #selector(onBackgroundChose))
        // System PiP auto-start / stop (AVKit requires start while scene is still foregroundActive).
        observe(UIScene.willDeactivateNotification, #selector(sceneWillDeactivateForPiP(_:)))
        observe(UIApplication.willEnterForegroundNotification, #selector(applicationWillEnterForegroundForPiP(_:)))
        observe(UIApplication.didBecomeActiveNotification, #selector(applicationDidBecomeActiveForPiP(_:)))
    }
    
    private func connectToRoomIfNeeded() {
        guard connectionManager.connectionState == .disconnected else { return }
        presentLoadingVC()
        
        let analyticsManager = SettingsManager.shared.analyticsManager
        if (AnalyticsManager.getDefaultInsightServerUrl().isEmpty == false && analyticsManager.isInsightsServiceEnabled() == false) {
            analyticsManager.startInsightsService(withEnteredData: AnalyticsManager.getDefaultInsightServerUrl());
        }
        
        if let guestParams = connectParams as? GuestData {
            connectionManager.connectToRoom(withData: guestParams)
        } else if let userParams = connectParams as? UserData {
            connectionManager.connectToRoom(withData: userParams)
        }
    }
    
    private func prepareUI() {
        cameraControlContainer.layer.cornerRadius = 6
        shareScreenLabelContainer.layer.cornerRadius = 12
        shareScreenLabelContainer.isHidden = !isBroadcastStarted
        // Toolbar
        toolbar.delegate = self
        toolbar.prepareForUse(with: toolbarContainer.frame, vc: self)
        toolbarContainer.addSubview(toolbar)
        setDefaultConstraints(forView: toolbarContainer, subview: toolbar)
        // Camera PTZ
        cameraPtz.onCloseButtonPressed = { self.hideCameraControlView() }
        cameraControlContainer.addSubview(cameraPtz)
        setDefaultConstraints(forView: cameraControlContainer, subview: cameraPtz)
    }
    
    private func prepareChatManager() {
        chatManager.startObservingChatEvents()
        chatManager.conferenceHandler = { [weak self] in
            guard let self = self else { return }
            self.updateToolbarBadges()
        }
    }
    
    private func prepareConnectionHandlers() {
        connectionManager.onConnectionSuccessHandler = {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.connectionManager.connectionState = .connected
                // Re-arm System PiP auto-start now that the call is live.
                self.blockSystemPiPBackgroundStart = false
                self.toolbar.updatePreferenceImages()
                self.loadingVC.dismiss()
                self.configureSystemPiPIfNeeded()
                NotificationCenter.default.post(name: .conferenceAvailable, object: nil)
            }
        }
        connectionManager.onConnectionFailureHandler = {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.loadingVC.dismiss()
                self.dismiss(animated: true) { [weak self] in
                    self?.presentFailToConnectAlert()
                }
            }
        }
        connectionManager.onDisconnectionHandler = { [weak self] in
            // Block late PiP starts and tear down before connection state flips.
            self?.blockSystemPiPBackgroundStart = true
            self?.tearDownSystemPiP()
            self?.connectionManager.connectionState = .disconnected
            self?.showConnectionMessage(" Disconnected.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let self = self else { return }
                self.isBroadcastStarted = false
                self.loadingVC.dismiss()
                
                self.dismiss(animated: true) {
                    self.hideVideoView()
                    self.preferences.updateDisabledStates()
                }
                
                NotificationCenter.default.post(name: .noConferenceAvailable, object: nil)
            }
            chatManager.clearData()
        }
    }
    
    private func prepareConferenceModeHandlers() {
        connectionManager.onConferenceModeChangedHandler = { isLobby in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLobbyMode = isLobby
                if isLobby {
                    self.onLobbyMode()
                } else {
                    self.lobbyInfo.startCountdown()
                }
            }
        }
        connectionManager.onConnectionPropertiesChangedHandler = { roomName in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.lobbyInfo.setInfo(roomName: roomName)
            }
        }
        lobbyInfo.onConferenceAvailableHandler = {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.exitLobbyMode()
            }
        }
    }
    
    private func prepareAutoReconnectHandlers() {
        connectionManager.onConferenceReconnectingHandler = { [weak self] attempt in
            var message = " %@ attempt to reconnect..."
            if let attemtsStr = attempt.ordinalString {
                message = String(format: message, attemtsStr)
            } else {
                message = " Reconnecting..."
            }
            self?.showConnectionMessage(message)
        }
        connectionManager.onConferenceReconnectedHandler = { [weak self] in
            self?.hideConnectionMessage()
        }
        connectionManager.onConferenceLostHandler = { [weak self] in
            self?.showConnectionMessage(" Conference lost.")
        }
    }
    
    private func prepareModerationHandlers() {
        moderationManager.onRaiseHandResponseApprovedHandler = { [weak self] in
            self?.handleRaiseHandResponse(withMessage: Constants.ModerationResponse.approved)
        }
        moderationManager.onRaiseHandResponseDismissedHandler = { [weak self] in
            self?.handleRaiseHandResponse(withMessage: Constants.ModerationResponse.dismissed)
        }
        moderationManager.onHardMuteHandler = { [weak self] (deviceType, state) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updatePreferencesAfterModeration(deviceType: deviceType, state: state)
                self.toolbar.updateRaiseHandButton(handState: self.moderationManager.handState)
            }
        }
        moderationManager.onSoftMuteHandler = { [weak self] deviceType in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updatePreferencesAfterModeration(deviceType: deviceType)
            }
        }
    }
    
    private func handleRaiseHandResponse(withMessage message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showPopoverMessage(
                sourceView: self.toolbar.raiseHandButton,
                message: message
            )
            self.toolbar.updateRaiseHandButton(handState: self.moderationManager.handState)
        }
    }
    
    private func updatePreferencesAfterModeration(deviceType: VCDeviceType, state: Bool? = nil) {
        let modirationState: DeviceState = (state == nil || state == false) ? .muted : .disabled
        switch deviceType {
        case .localCamera:
            toolbar.onCameraModerated(withState: state)
            preferences.setState(for: .camera, state: modirationState)
        case .localMicrophone:
            toolbar.onMicModerated(withState: state)
            preferences.setState(for: .mic, state: modirationState)
        default: break
        }
        toolbar.updatePreferenceImages()
    }
    
    private func onLobbyMode() {
        renderer.hideView(&self.videoView)
        if !preferences.getCurrentState(of: .camera) { // if camera unmuted
            connector.changeDevicePrivacy(forOption: .camera, specificState: true)
            toolbar.updatePreferenceImages()
        }
        toolbar.updateButtonsStatesOnConfereceModeChanged(isLobbyMode)
        changeToolbarConstraints(withValue: false)
        
        showLobbyView()
    }
    
    private func exitLobbyMode() {
        toolbar.updateButtonsStatesOnConfereceModeChanged(isLobbyMode)
        lobbyViewContainer.isHidden = !isLobbyMode
        refreshVideoView()
    }
    
    func updateToolbarBadges() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.toolbar.setNewMessagesNumber(chatManager.newMessagesTotalNumber)
        }
    }
    
    func refreshVideoView() {
        guard !isLobbyMode else { return }
        
        /*
         *  Delay of 250 milliseconds so that main thread can get the time to render the UI.
         */
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {  [weak self] in
            guard let self = self else { return }
            self.renderer.showConferenceView(&self.videoView)
            self.renderer.setViewSize(&self.videoView, self.videoView.frame)
            self.videoView.bringSubviewToFront(self.shareScreenLabelContainer)
            // Keep PiP's AVKit source view in sync after composite renderer resize.
            if #available(iOS 15.0, *) {
                self.pipManager?.updateSourceView(self.videoView)
            }
            self.configureSystemPiPIfNeeded()
        }
    }

    // MARK: - System PiP
    // Auto-start only: configure once connected, start on willDeactivate, stop on foreground.
    // No PiP toolbar button in this sample.

    /// Creates / refreshes `PiPManager` when connected and `videoView` is in a window.
    private func configureSystemPiPIfNeeded() {
        guard #available(iOS 15.0, *) else { return }
        guard connectionManager.connectionState == .connected, !isLobbyMode else { return }
        // AVKit needs the source view attached to a window before ContentSource is valid.
        guard videoView.window != nil else { return }

        if pipDataSource == nil {
            pipDataSource = ConferencePiPDataSource(conference: self)
        }
        let manager = pipManager ?? PiPManager()
        manager.delegate = self
        pipManager = manager
        manager.configure(sourceView: videoView, dataSource: pipDataSource)
    }

    /// End-of-call / leave-screen cleanup. Prefer calling before disconnect completes.
    func tearDownSystemPiP() {
        guard #available(iOS 15.0, *) else {
            ConnectorManager.shared.setSystemPiPActive(false)
            return
        }
        let work = { [weak self] in
            guard let self = self else { return }
            self.pipManager?.tearDown(invalidate: true)
            self.pipManager = nil
            self.pipDataSource = nil
            ConnectorManager.shared.setSystemPiPActive(false)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    /// Home / app switcher: start PiP while scene is still `.foregroundActive`.
    @objc private func sceneWillDeactivateForPiP(_ notification: Notification) {
        guard #available(iOS 15.0, *) else { return }
        pipManager?.noteSceneWillDeactivate()
        let isCallActive = !blockSystemPiPBackgroundStart
            && connectionManager.connectionState == .connected
            && !isLobbyMode
        pipManager?.requestBackgroundStart(reason: "UISceneWillDeactivate",
                                           sceneState: view.window?.windowScene?.activationState,
                                           isCallActive: isCallActive)
    }

    /// Returning to the app: dismiss PiP and allow the next background cycle to auto-start again.
    @objc private func applicationWillEnterForegroundForPiP(_ notification: Notification) {
        guard #available(iOS 15.0, *) else { return }
        pipManager?.stop(force: true)
        pipManager?.resetBackgroundCycle()
    }

    @objc private func applicationDidBecomeActiveForPiP(_ notification: Notification) {
        guard #available(iOS 15.0, *) else { return }
        pipManager?.stop(force: true)
        // NeoIOS pattern: recreate AVKit controller while foreground via updateSourceView.
        // Dropping the old controller releases a stuck system bubble; the new one is ready
        // for the next Home → PiP start (never detach contentSource / never rebuild on deactivate).
        pipManager?.updateSourceView(videoView)
    }
    
    private func showConnectionMessage(_ message: String) {
        DispatchQueue.main.async {
            self.connectionControlLabel.text = message
            self.connectionControlLabel.isHidden = false
        }
    }
    
    private func showPopoverMessage(sourceView: UIView, message: String) {
        let vc = PopoverViewController()
        vc.modalPresentationStyle = .popover
        
        guard let popover = vc.popoverPresentationController else { return }
        popover.delegate = self
        popover.sourceView = sourceView
        
        vc.addMessage(message)
        present(vc, animated: true)
    }
    
    func showCameraControlView(withInfo info: RemoteControllableCamera) {
        cameraPtz.prepareToControl(with: info, manager: participantsManager.remoteCameraManager)
        cameraControlContainer.isHidden = false
        videoView.bringSubviewToFront(cameraControlContainer)
        toolbar.updateCameraControlButtonImage(forValue: false)
    }
    
    func showLobbyView() {
        lobbyViewContainer.addSubview(lobbyInfo)
        setDefaultConstraints(forView: lobbyViewContainer, subview: lobbyInfo)
        lobbyViewContainer.isHidden = false
        videoView.bringSubviewToFront(lobbyViewContainer)
    }
    
    private func hideConnectionMessage() {
        DispatchQueue.main.async {
            self.connectionControlLabel.isHidden = true
            self.refreshVideoView()
        }
    }
    
    private func hideCameraControlView() {
        DispatchQueue.main.async {
            self.cameraControlContainer.isHidden = true
            self.toolbar.updateCameraControlButtonImage(forValue: true)
        }
    }
    
    func presentLoadingVC() {
        loadingVC.modalPresentationStyle = .overCurrentContext
        loadingVC.modalTransitionStyle = .crossDissolve
        loadingVC.startLoading()
        present(loadingVC, animated: true, completion: nil)
    }
    
    private func presentFailToConnectAlert() {
        let alert = UIAlertController(title: "Connection attempt failed",
                                      message: "",
                                      preferredStyle: .alert)
        let action = UIAlertAction(title: "Dismiss", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true, completion: nil)
        }
        
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    func hideVideoView() {
        guard connectionManager.connectionState == .disconnected else { return }
        DispatchQueue.main.async { () in
            self.renderer.hideView(&self.videoView)
        }
    }
    
    func changeToolbarConstraints(withValue isActive: Bool) {
        let constraints = toolbarContainer.constraints
        let identifier = Constants.ConferenceToolbar.heightConstraintId
        guard let height = constraints.first(where: { $0.identifier == identifier} ) else { return }
        height.constant = isActive ? Constants.ConferenceToolbar.fullHeight : Constants.ConferenceToolbar.mainHeight
        toolbarContainer.layoutIfNeeded()
    }
    
    private func setDefaultConstraints(forView view: UIView, subview: UIView) {
        subview.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        subview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        view.rightAnchor.constraint(equalTo: subview.rightAnchor, constant: 0).isActive = true
        subview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
    }
}

// MARK: - PiPManagerDelegate

@available(iOS 15.0, *)
extension ConferenceViewController: PiPManagerDelegate {
    func pipManager(_ manager: PiPManager, didChangeActive isActive: Bool, canStart: Bool) {
        // `isSystemPiPActive` is already updated inside PiPManager; host can react to UI if needed.
        log.info("System PiP state changed: active=\(isActive), canStart=\(canStart)")
    }

    func pipManager(_ manager: PiPManager, didFailWith error: Error) {
        log.error("System PiP failed: \(error.localizedDescription)")
    }
}
