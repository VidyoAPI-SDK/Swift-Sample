//
//  MessagingManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 17.08.2021.
//

import Foundation
import VidyoClientIOS

class MessagingManager {
    private let connector = ConnectorManager.shared.connector
    
    init() {
        connector.registerMessageEventListener(self)
    }
    
    deinit {
        connector.unregisterMessageEventListener()
    }
    
    func sendGroupMessage(body: String) -> Bool {
        connector.sendChatMessage(body)
    }
    
    func sendPrivateMessage(body: String, participant: VCParticipant) -> Bool {
        connector.sendPrivateChatMessage(participant, message: body)
    }
    
    private func notify(chatType: VCChatMessageType, message: Message) {
        DispatchQueue.global(qos: .userInteractive).async {
            switch chatType {
            case .chat:
                NotificationCenter.default.post(
                    name: .groupChatMessageReceived,
                    object: nil,
                    userInfo: [UserInfoKey.groupMessage: message]
                )
            case .privateChat:
                NotificationCenter.default.post(
                    name: .privateChatMessageReceived,
                    object: nil,
                    userInfo: [UserInfoKey.privateChat: message]
                )
            default: return
            }
        }
    }
}

//MARK: - VCConnectorIRegisterMessageEventListener
extension MessagingManager: VCConnectorIRegisterMessageEventListener {
    func onChatMessageReceived(_ participant: VCParticipant!, chatMessage: VCChatMessage!) {
        guard let text = chatMessage.body else { return }
        let message = Message(sender: participant, text: String(text), date: Date())
        notify(chatType: chatMessage.type, message: message)
    }
}
