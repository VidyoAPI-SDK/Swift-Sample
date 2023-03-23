//
//  Message.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 15.08.2021.
//

import Foundation

struct Message: MessageProtocol {
    var sender: VCParticipant?
    var isSender: Bool
    var type: MessageType
    var text: String
    var date: Date
    
    var senderID: String {
        guard let id = sender?.userId else { return "" }
        return String(id)
    }
    var senderName: String {
        guard let name = sender?.name else { return "" }
        return String(name)
    }
    
    init(text: String, date: Date) {
        self.type = .message
        self.text = text
        self.date = date
        self.isSender = false
    }
    
    init(sender: VCParticipant, text: String, date: Date) {
        self.type = .message
        self.sender = sender
        self.text = text
        self.date = date
        self.isSender = true
    }
}
