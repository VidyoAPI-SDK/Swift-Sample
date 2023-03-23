//
//  ConferenceViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 26.05.2021.
//

import UIKit

class ConferenceViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var connectionControlLabel: UILabel!
    @IBOutlet weak var lobbyViewContainer: UIView!
    @IBOutlet weak var toolbarContainer: UIView!
    @IBOutlet weak var cameraControlContainer: UIView!
    @IBOutlet weak var shareScreenLabelContainer: UIView!
    
    // MARK: - Const & vars
    let loadingVC = LoadingViewController()
    let toolbar = ConferenceToolbar.loadFromNib()
    let cameraPtz = CameraControlView.loadFromNib()
    let lobbyInfo = LobbyInfoView.loadFromNib()
    
    var connectParams: ConnectionData?
    var pinnedParticipantID: String?
    
    var connector = ConnectorManager.shared
    var preferences = PreferencesManager.shared
    var connectionManager = ConnectorManager.shared.connectionManager
    var participantsManager = ConnectorManager.shared.participantManager
    var remoteShareManager = RemoteShareManager()
    var moderationManager = ModerationManager()
    
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateToolbarBadges()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addObservers()
        participantsManager.registerRemoteCamera()
        refreshVideoView()
        connectToRoomIfNeeded()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
        hideVideoView()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        refreshVideoView()
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
    
    @objc private func onBackgroundOpenned() {
     hideVideoView()
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
        observe(.onBackgroundOpenned, #selector(onBackgroundOpenned))
    }
    
    private func connectToRoomIfNeeded() {
        guard connectionManager.connectionState == .disconnected else { return }
        presentLoadingVC()
        
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
                self.toolbar.updatePreferenceImages()
                self.loadingVC.dismiss()
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
            self?.connectionManager.connectionState = .disconnected
            self?.showConnectionMessage(" Disconnected.")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isBroadcastStarted = false
                self.loadingVC.dismiss()
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
        connector.hideView(&videoView)
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
        DispatchQueue.main.async {
            self.toolbar.setNewMessagesNumber(chatManager.newMessagesTotalNumber)
        }
    }
    
    func refreshVideoView() {
        guard !isLobbyMode else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connector.assignView(&self.videoView)
            self.connector.showView(for: &self.videoView)
            self.videoView.bringSubviewToFront(self.shareScreenLabelContainer)
        }
    }
    
    private func showConnectionMessage(_ message: String) {
        DispatchQueue.main.async {
            self.connectionControlLabel.text = message
            self.connectionControlLabel.isHidden = false
            self.refreshVideoView()
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
    
    private func hideVideoView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connector.hideView(&self.videoView)
        }
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
    
    private func presentLoadingVC() {
        loadingVC.modalPresentationStyle = .overCurrentContext
        loadingVC.modalTransitionStyle = .crossDissolve
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
