//
//  ChatsManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.08.2021.
//

import Foundation
import VidyoClientIOS

let chatManager = ChatsManager.shared

extension Array {
    func isValidIndex(_ index : Int) -> Bool {
        return index < self.count
    }
}

class ChatsManager {
    static let shared = ChatsManager()
    
    private let messagingManager = MessagingManager()
    private let participantsManager = ConnectorManager.shared.participantManager
    private let queue = DispatchQueue(label: "com.chat.arrayAccess", attributes: .concurrent)

    var chatList = [Chat(isGroupChat: true)]
    
    var conferenceHandler: (() -> ())?
    var chatListHandler: (() -> ())?
    var chatEventsHandler: ((MessageProtocol) -> ())?
    var privateChatEventsHandler: ((MessageProtocol) -> ())?
    
    var participantsNumber: Int {
        participantsManager.participantsNumber
    }
    var newMessagesTotalNumber: Int {
        var number = 0
        queue.sync {
            chatList.forEach { number += $0.newMessageCount}
        }
        return number
    }
    
    private init() {}
    
    // MARK: - Methods
    func startObservingChatEvents() {
        addObservers()
    }
    
    func clearData() {
        queue.async(flags: .barrier) {
            self.chatList = [Chat(isGroupChat: true)]
            self.removeObservers()
        }
    }
    
    func updateChat(_ updatedChat: Chat?) {
        guard let updatedChat = updatedChat else { return }
        
        queue.async(flags: .barrier) {
            self.chatList = self.chatList.map { chat -> Chat in
                guard chat.id == updatedChat.id else { return chat }
                return updatedChat
            }
        }
    }
    
    func sendGroupMessage(body: String) -> Bool {
        messagingManager.sendGroupMessage(body: body)
    }
    
    func sendPrivateMessage(_ body: String, to participant: VCParticipant) -> Bool {
        messagingManager.sendPrivateMessage(body: body, participant: participant)
    }
    
    //MARK: - Objc selectors
    @objc private func onGroupChatMessageReceived(_ notification: Notification) {
        handleGroupChatMessagesReceiving(notification)
    }
    
    @objc private func onPrivateChatMessageReceived(_ notification: Notification) {
        handlePrivateChatMessagesReceiving(notification)
    }
    
    @objc private func onParticipantJoinedConference(_ notification: Notification) {
        handleParticipantEvents(notification, .joinedConference)
    }
    
    @objc private func onParticipantLeftConference(_ notification: Notification) {
        handleParticipantEvents(notification, .leftConference)
    }
    
    @objc private func onRemoteShareNotification(_ notification: Notification) {
        handleGroupChatNotification(notification)
    }
    
    private func addObservers() {
        observe(.groupChatMessageReceived, #selector(onGroupChatMessageReceived))
        observe(.privateChatMessageReceived, #selector(onPrivateChatMessageReceived))
        observe(.participantJoinedConference, #selector(onParticipantJoinedConference))
        observe(.participantLeftConference, #selector(onParticipantLeftConference))
        observe(.remoteShareStarted, #selector(onRemoteShareNotification))
        observe(.remoteShareFinished, #selector(onRemoteShareNotification))
    }
    
    private func observe(_ name: NSNotification.Name?, _ selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - Private helpers
    private func handleGroupChatMessagesReceiving(_ notification: Notification) {
        guard let message = notification.userInfo?[UserInfoKey.groupMessage] as? Message else {
            log.info("Cannot get user data: \(#function).")
            return
        }
        print(message)
        
        queue.async(flags: .barrier) {
            guard !self.chatList.isEmpty else { return }
            self.chatList[0].messages.append(message)
            self.chatList[0].newMessageCount += 1
        }
        
        conferenceHandler?()
        chatListHandler?()
        chatEventsHandler?(message)
    }
    
    private func handlePrivateChatMessagesReceiving(_ notification: Notification) {
        guard let message = notification.userInfo?[UserInfoKey.privateChat] as? Message else {
            log.error("Cannot get user data: \(#function).")
            return
        }
        guard let index = chatList.firstIndex(where: { $0.id == message.senderID}) else {
            log.error("No chat with \(message.senderName) found.")
            return
        }
        queue.async(flags: .barrier) {
            self.chatList[index].messages.append(message)
            self.chatList[index].newMessageCount += 1
        }
        
        conferenceHandler?()
        chatListHandler?()
        privateChatEventsHandler?(message)
    }
    
    private func handleGroupChatNotification(_ notification: Notification) {
        guard let notification = notification.userInfo?[UserInfoKey.notification] as? ChatNotification else {
            log.info("Cannot get user data: \(#function).")
            return
        }
        queue.async(flags: .barrier) {
            guard !self.chatList.isEmpty else { return }
            self.chatList[0].messages.append(notification)
        }
        conferenceHandler?()
        chatListHandler?()
        chatEventsHandler?(notification)
    }
    
    private func handleParticipantEvents(_ notification: Notification, _ event: ChatNotificationEventType) {
        guard let participant = notification.userInfo?[UserInfoKey.participant] as? VCParticipant else {
            log.info("Cannot get user data: \(#function).")
            return
        }
        guard !participant.isLocal() else { return }
        
        if event == .joinedConference {
            updateChatListWhenJoined(participant)
        } else if event == .leftConference {
            updateChatListWhenLeft(participant)
        }

        conferenceHandler?()
        chatListHandler?()
        
        handleGroupChatNotification(notification)
    }
    
    private func chatExists(forParticipant participant: VCParticipant) -> Bool {
        queue.sync {
            chatList.first(where: { $0.id == String(participant.id) }) != nil
        }
    }
    
    private func getIndex(forParticipant participant: VCParticipant) -> Int? {
        queue.sync {
            chatList.firstIndex(where: { $0.id == String(participant.id)})
        }
    }

    private func updateChatListWhenJoined(_ participant: VCParticipant) {
        if chatExists(forParticipant: participant) {
            if let index = getIndex(forParticipant: participant) {
                queue.async(flags: .barrier) {
                    self.chatList[index].isActive = true
                    self.chatList[index].participant = participant
                }
            }
        } else {
            let newChat = Chat(participant: participant)
            queue.async(flags: .barrier) {
                self.chatList.append(newChat)
            }
        }
    }
    
    private func updateChatListWhenLeft(_ participant: VCParticipant) {
        guard let index = getIndex(forParticipant: participant) else { return }
        
        queue.async(flags: .barrier) {
            guard self.chatList.isValidIndex(index) else { return }
            
            if self.chatList[index].messages.isEmpty {
                self.chatList.remove(at: index)
            } else {
                self.chatList[index].isActive = false
            }
        }
    }
}
