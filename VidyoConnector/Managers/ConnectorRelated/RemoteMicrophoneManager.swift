//
//  RemoteMicrophoneManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 05.07.2021.
//

import Foundation

class RemoteMicrophoneManager {
    let connector = ConnectorManager.shared.connector
    
    var onRemoteMicrophoneStateUpdatedHandler: ((VCParticipant, VCDeviceState) -> ())?
    
    func registerRemoteMicrophoneEventListener() {
        connector.registerRemoteMicrophoneEventListener(self)
    }
    
    func unregisterRemoteMicrophoneEventListener() {
        connector.unregisterRemoteMicrophoneEventListener()
    }
}

//MARK: - VCConnectorIRegisterRemoteMicrophoneEventListener
extension RemoteMicrophoneManager: VCConnectorIRegisterRemoteMicrophoneEventListener {
    func onRemoteMicrophoneAdded(_ remoteMicrophone: VCRemoteMicrophone!, participant: VCParticipant!) {
        onRemoteMicrophoneStateUpdatedHandler?(participant, .added)
    }
    
    func onRemoteMicrophoneRemoved(_ remoteMicrophone: VCRemoteMicrophone!, participant: VCParticipant!) {
        onRemoteMicrophoneStateUpdatedHandler?(participant, .removed)
    }
    
    func onRemoteMicrophoneStateUpdated(_ remoteMicrophone: VCRemoteMicrophone!, participant: VCParticipant!, state: VCDeviceState) {
        onRemoteMicrophoneStateUpdatedHandler?(participant, state)
    }
}
