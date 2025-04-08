//
//  ChatNotification.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.08.2021.
//

import Foundation
import VidyoClientIOS

enum ChatNotificationEventType: String {
    case joinedConference = "joined the conference"
    case leftConference = "left the conference"
    case startedSharing = "started sharing"
    case stoppedSharing = "stopped sharing"
}

struct ChatNotification: MessageProtocol {
    let participant: VCParticipant
    let event: ChatNotificationEventType
    var type: MessageType
    var date: Date
    
    var participantID: String {
        String(participant.id)
    }
    var participantName: String {
        String(participant.name)
    }
    var text: String {
        return time + " " + participantName + " " + event.rawValue
    }
    
    init(participant: VCParticipant, event: ChatNotificationEventType) {
        self.participant = participant
        self.type = .notification
        self.event = event
        self.date = Date()
    }
}
