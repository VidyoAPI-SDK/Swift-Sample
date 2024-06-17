//
//  ConnectionHandlingManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 29.06.2021.
//

import Foundation
import VidyoClientIOS

class ConnectionHandlingManager {
    let connector = ConnectorManager.shared.connector
    var connectionState: ConnectionState
    
    var onConnectionSuccessHandler: (() -> ())?
    var onConnectionFailureHandler: (() -> ())?
    var onDisconnectionHandler: (() -> ())?
    
    var onConferenceReconnectingHandler: ((UInt32) -> ())?
    var onConferenceReconnectedHandler: (() -> ())?
    var onConferenceLostHandler: (() -> ())?
    
    var onConferenceModeChangedHandler: ((Bool) -> ())?
    var onConnectionPropertiesChangedHandler: ((String) -> ())?
    
    init() {
        connectionState = .disconnected
        connector.registerReconnectEventListener(self)
        connector.registerConferenceModeEventListener(self)
        connector.registerConnectionPropertiesEventListener(self)
    }
    
    deinit {
        connector.unregisterReconnectEventListener()
        connector.unregisterConferenceModeEventListener()
        connector.unregisterConnectionPropertiesEventListener()
    }
    
    //MARK: - Connection & disconnection
    func connectToRoom(withData connectData: GuestData) {
        connector.connectToRoom(
            asGuest: connectData.portalAddress,
            displayName: connectData.displayName,
            roomKey: connectData.roomKey,
            roomPin: connectData.roomPin,
            connectorIConnect: self
        )
    }
    
    func connectToRoom(withData connectData: UserData) {
        connector.connectToRoom(
            withKey: connectData.portalAddress,
            userName: connectData.username,
            password: connectData.password,
            roomKey: connectData.roomKey,
            roomPin: connectData.roomPin,
            connectorIConnect: self
        )
    }
    
    func disconnect() {
        connectionState = .disconnected
        connector.disconnect()
    }
    
    //MARK: - AutoReconnect
    func enableAutoReconnect(withValue enable: Bool) -> Bool {
        connector.setAutoReconnect(enable)
    }
    
    func setAutoReconnectMaxAttempts(_ attempts: UInt32) -> Bool {
        connector.setAutoReconnectMaxAttempts(attempts)
    }
    
    func setAutoReconnectAttemptBackOff(_ sec: UInt32) -> Bool {
        connector.setAutoReconnectAttemptBackOff(sec)
    }
}

// MARK: - VCConnectorIConnect
extension ConnectionHandlingManager: VCConnectorIConnect {
    func onSuccess() {
        onConnectionSuccessHandler?()
    }
    
    func onFailure(_ reason: VCConnectorFailReason) {
        onConnectionFailureHandler?()
    }
    
    func onDisconnected(_ reason: VCConnectorDisconnectReason) {
        onDisconnectionHandler?()
    }
}

// MARK: - VCConnectorIRegisterReconnectEventListener
extension ConnectionHandlingManager: VCConnectorIRegisterReconnectEventListener {
    func onReconnecting(_ attempt: UInt32, attemptTimeout: UInt32, reason: VCConnectorFailReason) {
        onConferenceReconnectingHandler?(attempt)
    }
    
    func onReconnected() {
        onConferenceReconnectedHandler?()
    }
    
    func onConferenceLost(_ reason: VCConnectorFailReason) {
        onConferenceLostHandler?()
    }
}

// MARK: - VCConnectorIRegisterConferenceModeEventListener
extension ConnectionHandlingManager: VCConnectorIRegisterConferenceModeEventListener {
    func onConferenceModeChanged(_ mode: VCConnectorConferenceMode) {
        onConferenceModeChangedHandler?(mode == .LOBBY)
    }
}

// MARK: - VCConnectorIRegisterConnectionPropertiesEventListener
extension ConnectionHandlingManager: VCConnectorIRegisterConnectionPropertiesEventListener {
    func onConnectionPropertiesChanged(_ connectionProperties: VCConnectorConnectionProperties!) {
        let roomName = String(connectionProperties.roomName)
        guard !roomName.isEmpty else { return }
        onConnectionPropertiesChangedHandler?(roomName)
    }
}
