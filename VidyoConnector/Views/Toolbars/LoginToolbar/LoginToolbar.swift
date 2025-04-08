//
//  LoginToolbar.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 31.05.2021.
//

import UIKit
import VidyoClientIOS

class LoginToolbar: UIToolbar {
    
    // MARK: - IBOutlets
    @IBOutlet weak var speakerBarButton: UIBarButtonItem!
    @IBOutlet weak var micBarButton: UIBarButtonItem!
    @IBOutlet weak var cameraBarButton: UIBarButtonItem!
    @IBOutlet weak var backgroundBarButton: UIBarButtonItem!
    
    var preferences = PreferencesManager.shared
    var settingsManager = SettingsManager.shared
    var presentNavigationControllerHandler: ((UINavigationController) -> ())?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        settingsManager.setDelegate(self)
    }

    // MARK: - IBActions
    @IBAction func settingsBarButtonPressed(_ sender: UIBarButtonItem) {
        let nc: UINavigationController = InstantiateFromStoryboardFactory().instantiateNavigationController(with: .settingsNC)
        nc.modalPresentationStyle = .fullScreen
        presentNavigationControllerHandler?(nc)
    }
 
    @IBAction func speakerStateChanged(_ sender: UIBarButtonItem) {
        ConnectorManager.shared.changeDevicePrivacy(forOption: .speaker)
        updatePreferenceImages()
    }
    
    @IBAction func micStateChanged(_ sender: UIBarButtonItem) {
        ConnectorManager.shared.changeDevicePrivacy(forOption: .mic)
        updatePreferenceImages()
    }
    
    @IBAction func cameraStateChanged(_ sender: UIBarButtonItem) {
        ConnectorManager.shared.changeDevicePrivacy(forOption: .camera)
        updatePreferenceImages()
    }
    
    @IBAction func chooseBgBarButtonPressed(_ sender: UIBarButtonItem) {
        backgroundBarButton.image = UIImage(named: Constants.Icon.backgroundActive)
        let factory = InstantiateFromStoryboardFactory()
        let nc: UINavigationController = factory.instantiateNavigationController(with: .backgroundNC)
        nc.modalPresentationStyle = .overCurrentContext
        presentNavigationControllerHandler?(nc)
    }    
    
    func updatePreferenceImages() {
        speakerBarButton.image = UIImage(named: preferences.getProperImageName(for: .speaker))
        micBarButton.image = UIImage(named: preferences.getProperImageName(for: .mic))
        cameraBarButton.image = UIImage(named: preferences.getProperImageName(for: .camera))
    }
    
    func updateBackgroundButton() {
        backgroundBarButton.image = UIImage(named: Constants.Icon.background)
    }
}

// MARK: - LocalDeviceStateUpdatedDelegate
extension LoginToolbar: LocalDeviceStateUpdatedDelegate {
    func onLocalDeviceStateUpdated(type: PreferencesOption, state: VCDeviceState) {
        preferences.handleStateUpdated(type: type, state: state)
        updatePreferenceImages()
    }
    
    func onOtherDeviceStateUpdated(type: PreferencesOption, state: DeviceState) {
    }
}
