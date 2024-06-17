//
//  Participant.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 08.07.2021.
//

import Foundation
import VidyoClientIOS

struct Participant {
    private let clearanceType: VCParticipantClearanceType
    
    let id: String
    let name: String
    let isLocal: Bool
    
    var isMicMuted: Bool = true
    var isCameraMuted: Bool = true
    var isCameraControllable: Bool = false
    var isPinned: Bool = false
    
    var type: String {
        switch clearanceType {
        case .PARTICIPANT_CLEARANCETYPE_Owner:
            return "Host"
        case .PARTICIPANT_CLEARANCETYPE_None:
            return "Guest"
        default:
            return ""
        }
    }
    
    init(_ participant: VCParticipant) {
        id = participant.getId()
        name = participant.getName()
        isLocal = participant.isLocal()
        clearanceType = participant.getClearanceType()
    }
}
