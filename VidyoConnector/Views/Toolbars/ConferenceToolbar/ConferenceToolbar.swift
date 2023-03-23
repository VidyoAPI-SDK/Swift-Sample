//
//  ConferenceSecondToolbar.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 02.08.2021.
//

import UIKit

// MARK: - ToolbarDelegate
protocol ToolbarDelegate {
    // Main
    func onEndCallButtonPressed()
    func onSettingsButtonPressed()
    func onSpeakerButtonPressed()
    func onMicButtonPressed()
    func onCameraButtonPressed()
    func onMoreButtonPressed(isActive: Bool)
    // More
    func onCameraControlButtonPressed(_ view: UIView)
    func onBackgroundButtonPressed()
    func onRaiseHandButtonPressed()
    func onChatButtonPressed()
    func onParticipantsButtonPressed()
    func onMultipleShareButtonPressed()
    func onScreenShareButtonPressed()
    func onModeratorButtonPressed()
}

// MARK: - ConferenceToolbar
class ConferenceToolbar: UIView {
    @IBOutlet weak var endCallButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var micButton: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var moreButton: UIButton!
    // More
    @IBOutlet weak var additionalToolbar: UIStackView!
    @IBOutlet weak var mockView: UIView!
    @IBOutlet weak var cameraPTZButton: UIButton!
    @IBOutlet weak var backgroundButton: UIButton!
    @IBOutlet weak var raiseHandButton: UIButton!
    @IBOutlet weak var chatButton: UIButton!
    @IBOutlet weak var participantsButton: UIButton!
    @IBOutlet weak var multipleShareButton: UIButton!
    @IBOutlet weak var screenShareButton: UIButton!
    @IBOutlet weak var moderatorButton: UIButton!
    //Badges Label
    @IBOutlet weak var chatBadgeLabel: UILabel!
    @IBOutlet weak var participantsBadgeLabel: UILabel!
    @IBOutlet weak var moreBadgeLabel: UILabel!

    // MARK: - Const & vars
    let badgeCrnerRadius: CGFloat = 8

    var delegate: ToolbarDelegate?
    var conferenceVC: ConferenceViewController?
    var preferences = PreferencesManager.shared
    var settingsManager = SettingsManager.shared
    
    var newMessagesCount = 0
    var isLobbyMode: Bool = false
    
    var newMessagesCountString: String? {
        guard newMessagesCount != 0 else { return nil }
        return newMessagesCount > 9 ? "9+" : String(newMessagesCount)
    }
    var isMockViewHidden: Bool {
        !cameraPTZButton.isHidden || !raiseHandButton.isHidden || !multipleShareButton.isHidden
    }
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        addObservers()
        prepareBadges()
        hideProperButtons()
        updatePreferenceImages()
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false
        settingsManager.setDelegate(self)
    }
    
    deinit {
        removeObservers()
    }
    
    //MARK: - IBActions
    @IBAction func endCallButtonPressed(_ sender: UIButton) {
        delegate?.onEndCallButtonPressed()
    }
    
    @IBAction func settingsButtonPressed(_ sender: UIButton) {
        delegate?.onSettingsButtonPressed()
    }
    
    @IBAction func speakerButtonPressed(_ sender: UIButton) {
        delegate?.onSpeakerButtonPressed()
    }
    
    @IBAction func micButtonPressed(_ sender: UIButton) {
        delegate?.onMicButtonPressed()
    }
    
    @IBAction func cameraButtonPressed(_ sender: UIButton) {
        delegate?.onCameraButtonPressed()
    }
    
    @IBAction func moreButtonPressed(_ sender: UIButton) {
        additionalToolbar.isHidden = !additionalToolbar.isHidden
        updateBadges()
        let image = UIImage(named: additionalToolbar.isHidden ? Constants.Icon.moreDisabled : Constants.Icon.more)
        moreButton.setImage(image, for: .normal)
        delegate?.onMoreButtonPressed(isActive: !additionalToolbar.isHidden)
    }
    
    @IBAction func cameraPTZButtonPressed(_ sender: UIButton) {
        delegate?.onCameraControlButtonPressed(sender)
    }
    
    @IBAction func backgroundButtonPressed(_ sender: UIButton) {
        delegate?.onBackgroundButtonPressed()
    }
    
    @IBAction func raiseHandButtonPressed(_ sender: UIButton) {
        delegate?.onRaiseHandButtonPressed()
    }
    
    @IBAction func chatButtonPressed(_ sender: UIButton) {
        delegate?.onChatButtonPressed()
    }
    
    @IBAction func participantsButtonPressed(_ sender: UIButton) {
        delegate?.onParticipantsButtonPressed()
    }
    
    @IBAction func multipleShareButtonPressed(_ sender: UIButton) {
        delegate?.onMultipleShareButtonPressed()
    }
    
    @IBAction func screenShareButtonPressed(_ sender: UIButton) {
        delegate?.onScreenShareButtonPressed()
    }
    
    @IBAction func moderatorButtonPressed(_ sender: UIButton) {
        delegate?.onModeratorButtonPressed()
    }
    
    // MARK: - Methods
    @objc private func onRemoteCameraControlAvailable() {
        DispatchQueue.main.async {
            self.cameraPTZButton.isHidden = false
            self.mockView.isHidden = self.isMockViewHidden
        }
    }
    
    @objc private func onNoRemoteCameraToControl() {
        DispatchQueue.main.async {
            self.cameraPTZButton.isHidden = true
            self.mockView.isHidden = self.isMockViewHidden
        }
    }
    
    private func addObservers() {
        observe(.remoteCameraControlAvailable, #selector(onRemoteCameraControlAvailable))
        observe(.noRemoteCameraToControl, #selector(onNoRemoteCameraToControl))
    }
    
    private func observe(_ name: NSNotification.Name?, _ selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func prepareBadges() {
        chatBadgeLabel.layer.cornerRadius = badgeCrnerRadius
        moreBadgeLabel.layer.cornerRadius = badgeCrnerRadius
        participantsBadgeLabel.layer.cornerRadius = badgeCrnerRadius
        
        chatBadgeLabel.isHidden = true
        moreBadgeLabel.isHidden = true
        participantsBadgeLabel.isHidden = true
        
        chatBadgeLabel.text = nil
        moreBadgeLabel.text = nil
        participantsBadgeLabel.text = nil
    }
    
    private func hideProperButtons() {
        additionalToolbar.isHidden = true
        cameraPTZButton.isHidden = true
        multipleShareButton.isHidden = true
        showRaiseHandButtonIfNeeded()
    }
    
    private func showRaiseHandButtonIfNeeded() {
        if !micButton.isEnabled || !cameraButton.isEnabled {
            raiseHandButton.isHidden = false
        }
        mockView.isHidden = isMockViewHidden
    }
    
    private func hideRaiseHandButtonIfNeeded(handState: HandState) {
        if micButton.isEnabled && cameraButton.isEnabled && handState == .unraised {
            raiseHandButton.isHidden = true
        }
        mockView.isHidden = isMockViewHidden
    }
    
    private func changeRaiseHandButtonIcon(handState: HandState) {
        switch handState {
        case .raised:
            let image = UIImage(named: Constants.Icon.unraiseHand)
            raiseHandButton.setImage(image, for: .normal)
        case .unraised:
            let image = UIImage(named: Constants.Icon.raiseHand)
            raiseHandButton.setImage(image, for: .normal)
        }
    }
    
    func prepareForUse(with frame: CGRect, vc: ConferenceViewController) {
        self.frame = frame
        conferenceVC = vc
    }
    
    func onCameraModerated(withState state: Bool?) {
        guard let state = state else { return }
        cameraButton.isEnabled = !isLobbyMode && !state
        backgroundButton.isEnabled = !state
    }
    
    func onMicModerated(withState state: Bool?) {
        guard let state = state else { return }
        micButton.isEnabled = !isLobbyMode && !state
    }
    
    func updatePreferenceImages() {
        speakerButton.setImage(UIImage(named: preferences.getProperImageName(for: .speaker)), for: .normal)
        micButton.setImage(UIImage(named: preferences.getProperImageName(for: .mic)), for: .normal)
        cameraButton.setImage(UIImage(named: preferences.getProperImageName(for: .camera)), for: .normal)
    }
    
    func updateCameraControlButtonImage(forValue isFeccAvailable: Bool) {
        let image = isFeccAvailable ? UIImage(named: Constants.Icon.fecc) : UIImage(named: Constants.Icon.feccActive)
        cameraPTZButton.setImage(image, for: .normal)
    }
    
    func updateShareScreenButtonImage(forValue isBroadcasting: Bool) {
        let image = isBroadcasting ? UIImage(named: Constants.Icon.shareActive) : UIImage(named: Constants.Icon.share)
        screenShareButton.setImage(image, for: .normal)
    }
    
    func updateBackgroundButton(forValue isActive: Bool = false) {
        let image = UIImage(named: isActive ? Constants.Icon.backgroundActive : Constants.Icon.background)
        backgroundButton.setImage(image, for: .normal)
    }
    
    func updateRaiseHandButton(handState: HandState? = nil) {
        if raiseHandButton.isHidden {
            showRaiseHandButtonIfNeeded()
        } else {
            guard let state = handState else { return }
            changeRaiseHandButtonIcon(handState: state)
            hideRaiseHandButtonIfNeeded(handState: state)
        }
    }
    
    func updateButtonsStatesOnConfereceModeChanged(_ isLobby: Bool) {
        isLobbyMode = isLobby
        if isLobby, !additionalToolbar.isHidden {
            additionalToolbar.isHidden = true
        }
        settingsButton.isEnabled = !isLobby
        speakerButton.isEnabled = !isLobby
        moreButton.isEnabled = !isLobby
                
        micButton.isEnabled = !isLobby && preferences.micState != .disabled
        cameraButton.isEnabled = !isLobby && preferences.cameraState != .disabled
    }
    
    func setNewMessagesNumber(_ count: Int) {
        newMessagesCount = count
        guard newMessagesCount != 0 else {
            chatBadgeLabel.isHidden = true
            moreBadgeLabel.isHidden = true
            return
        }
        updateBadges()
    }
    
    func updateBadges() {
        guard newMessagesCount != 0 else { return }
        if additionalToolbar.isHidden {
            moreBadgeLabel.text = newMessagesCountString
            moreBadgeLabel.isHidden = false
        } else {
            chatBadgeLabel.text = newMessagesCountString
            chatBadgeLabel.isHidden = false
            moreBadgeLabel.isHidden = true
        }
    }
}

// MARK: - LocalDeviceStateUpdatedDelegate
extension ConferenceToolbar: LocalDeviceStateUpdatedDelegate {
    func onLocalDeviceStateUpdated(type: PreferencesOption, state: VCDeviceState) {
        preferences.handleStateUpdated(type: type, state: state)
        updatePreferenceImages()
    }
}
