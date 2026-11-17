//
//  RemoteShareManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.08.2021.
//

import Foundation
import VidyoClientIOS

class RemoteShareManager {
    let connector = ConnectorManager.shared.connector
    
    init() {
        connector.registerRemoteWindowShareEventListener(self)
    }
    
    deinit {
        connector.unregisterRemoteWindowShareEventListener()
    }
    
    func notify(_ notificationName: Notification.Name, event: ChatNotificationEventType, participant: VCParticipant) {
        DispatchQueue.global(qos: .userInteractive).async {
            let notification = ChatNotification(participant: participant, event: event)
            NotificationCenter.default.post(
                name: notificationName,
                object: nil,
                userInfo: [UserInfoKey.notification: notification]
            )
        }
    }
}

//MARK: - VCConnectorIRegisterRemoteWindowShareEventListener
extension RemoteShareManager: VCConnectorIRegisterRemoteWindowShareEventListener {
    func onRemoteWindowShareAdded(_ remoteWindowShare: VCRemoteWindowShare!, participant: VCParticipant!) {
        notify(.remoteShareStarted, event: .startedSharing, participant: participant)
    }
    
    func onRemoteWindowShareRemoved(_ remoteWindowShare: VCRemoteWindowShare!, participant: VCParticipant!) {
        notify(.remoteShareFinished, event: .stoppedSharing, participant: participant)
    }
    
    func onRemoteWindowShareStateUpdated(_ remoteWindowShare: VCRemoteWindowShare!, participant: VCParticipant!, state: VCDeviceState) {}
}
