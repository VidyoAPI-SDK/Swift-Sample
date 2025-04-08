//
//  ConferenceViewController+ToolbarDelegate.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 08.08.2021.
//

import UIKit

extension ConferenceViewController: ToolbarDelegate {
    func onEndCallButtonPressed() {
        if connectionManager.connectionState == .connected {
            connectionManager.disconnect()
            NotificationCenter.default.post(name: .noConferenceAvailable, object: nil)
            self.presentLoadingVC()
        }
    }
    
    func onSettingsButtonPressed() {
        let nc: UINavigationController = InstantiateFromStoryboardFactory().instantiateNavigationController(with: .settingsNC)
        nc.modalPresentationStyle = .fullScreen
        present(nc, animated: true, completion: nil)
    }
    
    func onSpeakerButtonPressed() {
        connector.changeDevicePrivacy(forOption: .speaker)
        toolbar.updatePreferenceImages()
    }
    
    func onMicButtonPressed() {
        connector.changeDevicePrivacy(forOption: .mic)
        toolbar.updatePreferenceImages()
    }
    
    func onCameraButtonPressed() {
        connector.changeDevicePrivacy(forOption: .camera)
        toolbar.updatePreferenceImages()
    }
    
    func onMoreButtonPressed(isActive: Bool) {
        changeToolbarConstraints(withValue: isActive)
        toolbar.updateRaiseHandButton(handState: moderationManager.handState)
        refreshVideoView()
    }
    
    func onTorchButtonPressed() {
        connector.changeDevicePrivacy(forOption: .torch)
        toolbar.updatePreferenceImages()
        refreshVideoView()
    }
    
    //MARK: - More
    func onMultipleShareButtonPressed(){}
    func onModeratorButtonPressed(){}
    
    func onCameraControlButtonPressed(_ view: UIView) {
        guard participantsManager.isControllableCameraAvailable else { return }
        
        let actionSheet = RemoteCameraControlActionSheet(
            shareManager: participantsManager.remoteCameraManager,
            destination: self
        )
        actionSheet.onActionSelectedHandler = { info in
            self.showCameraControlView(withInfo: info)
        }
        actionSheet.present(from: view)
    }
    
    func onBackgroundButtonPressed() {
        toolbar.updateBackgroundButton(forValue: true)
        let factory = InstantiateFromStoryboardFactory()
        let nc: UINavigationController = factory.instantiateNavigationController(with: .backgroundNC)
        nc.modalPresentationStyle = .overCurrentContext
        present(nc, animated: true, completion: nil)
    }
    
    func onRaiseHandButtonPressed() {
        let handState = moderationManager.handleRaiseHandRequest()
        toolbar.updateRaiseHandButton(handState: handState)
    }
    
    func onChatButtonPressed() {
        let factory = InstantiateFromStoryboardFactory()
        let nc: UINavigationController = factory.instantiateNavigationController(with: .chatNC)
        nc.modalPresentationStyle = .fullScreen
        present(nc, animated: true, completion: nil)
    }
    
    func onParticipantsButtonPressed() {
        participantsManager.unregisterRemoteCamera()
        
        let participantsVC: ParticipantsViewController = InstantiateFromStoryboardFactory().instantiateFromStoryboard()
        participantsVC.modalPresentationStyle = .fullScreen
        
        participantsVC.pinnedParticipantFromConference = pinnedParticipantID
        participantsVC.participantManager = participantsManager
        participantsVC.passPinnedParticipantHandler = { pinnedOne in
            self.pinnedParticipantID = pinnedOne
        }
        present(participantsVC, animated: true, completion: nil)
    }
    
    func onScreenShareButtonPressed() {
        let vc: ScreenSharingAlertViewController = InstantiateFromStoryboardFactory().instantiateFromStoryboard()
        present(vc, animated: true, completion: nil)
    }
}

extension ConferenceViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}
