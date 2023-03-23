//
//  NotificationNameExtension.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 30.07.2021.
//

import Foundation

extension Notification.Name {
    
    //MARK: - Screen share
    static let conferenceBroadcastStarted = Notification.Name("conferenceBroadcastStarted")
    static let conferenceBroadcastFinished = Notification.Name("conferenceBroadcastFinished")
    static let shareBroadcastStarted = Notification.Name("shareBroadcastStarted")
    static let shareBroadcastFinished = Notification.Name("shareBroadcastFinished")
    static let remoteShareStarted = Notification.Name("remoteShareStarted")
    static let remoteShareFinished = Notification.Name("remoteShareFinished")
    
    //MARK: - Connection
    static let conferenceAvailable = Notification.Name("conferenceAvailable")
    static let noConferenceAvailable = Notification.Name("noConferenceAvailable")
    
    //MARK: - Paricipants
    static let participantJoinedConference = Notification.Name("participantJoinedConference")
    static let participantLeftConference = Notification.Name("participantLeftConference")
    
    //MARK: - Camera control
    static let remoteCameraControlAvailable = Notification.Name("remoteCameraControlAvailable")
    static let noRemoteCameraToControl = Notification.Name("noRemoteCameraToControl")
    
    //MARK: - Chat
    static let groupChatMessageReceived = Notification.Name("groupChatMessageReceived")
    static let privateChatMessageReceived = Notification.Name("privateChatMessageReceived")

    //MARK: - Camera background
    static let onBackgroundChose = Notification.Name("onBackgroundChose")
    static let onBackgroundOpenned = Notification.Name("onBackgroundOpenned")
}
