//
//  ModerationManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 15.09.2021.
//

import Foundation
import VidyoClientIOS

enum HandState {
    case raised
    case unraised
}

class ModerationManager {
    
    private let connector = ConnectorManager.shared.connector
    private let requestID = UUID().uuidString
    private(set) var handState: HandState = .unraised
    
    var onHardMuteHandler: ((VCDeviceType, Bool)->())?
    var onSoftMuteHandler: ((VCDeviceType)->())?
    var onRaiseHandResponseApprovedHandler: (()->())?
    var onRaiseHandResponseDismissedHandler: (()->())?
    
    init() {
        connector.registerModerationCommandEventListener(self)
    }
    
    deinit {
        connector.unregisterModerationCommandEventListener()
    }
    
    func handleRaiseHandRequest() -> HandState {
        switch handState {
        case .raised:
            if connector.unraiseHand(requestID) {
                handState = .unraised
            }
        case .unraised:
            if connector.raiseHand(self, requestId: requestID) {
                handState = .raised
            }
        }
        return handState
    }
}

//MARK: - VCConnectorIRaiseHand
extension ModerationManager: VCConnectorIRaiseHand {
    func onRaiseHandResponse(_ handState: VCParticipantHandState) {
        switch handState {
        case .APPROVED:
            onRaiseHandResponseApprovedHandler?()
        case .DISMISSED:
            self.handState = .unraised
            onRaiseHandResponseDismissedHandler?()
        default: return
        }
    }
}

//MARK: - VCConnectorIRegisterModerationCommandEventListener
extension ModerationManager: VCConnectorIRegisterModerationCommandEventListener {
    func onModerationCommandReceived(_ deviceType: VCDeviceType, moderationType: VCRoomModerationType, state: Bool) {
        switch moderationType {
        case .softMute: onSoftMuteHandler?(deviceType)
        case .hardMute: onHardMuteHandler?(deviceType, state)
        default: return
        }
    }
}

