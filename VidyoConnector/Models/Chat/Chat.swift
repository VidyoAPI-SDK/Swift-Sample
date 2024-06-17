//
//  Chat.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 12.08.2021.
//

import Foundation
import VidyoClientIOS

struct Chat {
    var id: String
    var name: String
    var avatarImage: UIImage?
    var participant: VCParticipant?
    var newMessageCount: Int = 0
    var isGroupChat: Bool
    var isActive: Bool
    
    var messages = [MessageProtocol]()
    
    var avatarInitials: String {
        name.initials
    }
    
    init() {
        self.id = ""
        self.name = ""
        self.avatarImage = nil
        self.isActive = false
        self.isGroupChat = false
    }
    
    init(participant: VCParticipant, avatarImage: UIImage? = nil) {
        self.id = String(participant.userId)
        self.name = String(participant.name)
        self.participant = participant
        self.avatarImage = avatarImage
        self.isActive = true
        self.isGroupChat = false
    }
    
    init(isGroupChat: Bool) {
        self.id = UUID().uuidString
        self.name = "Group Chat"
        self.avatarImage = Constants.Chat.groupChatImage
        self.isActive = isGroupChat
        self.isGroupChat = isGroupChat
    }
}
