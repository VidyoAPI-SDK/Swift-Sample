//
//  ParticipantsManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 05.07.2021.
//

import Foundation

class ParticipantsManager {
    let connector = ConnectorManager.shared.connector
    
    var remoteCameraManager = RemoteCameraManager()
    var remoteMicrophoneManager = RemoteMicrophoneManager()
    
    var participants = SynchronizedArray<VCParticipant>()
    var isLocalParticipantJoined = false

    var onParticipantMicrophoneStateUpdatedHandler: ((String, Bool) -> ())?
    var onParticipantCameraStateUpdatedHandler: ((String, Bool) -> ())?
    var onParticipantCameraAddedHandler: ((String) -> ())?
    var onParticipantCameraRemovedHandler: ((String) -> ())?
    
    var participantsNumber: Int {
        return participants.count
    }
    var isControllableCameraAvailable: Bool {
        !remoteCameraManager.remoteControllableCameras.isEmpty
    }
    
    init() {
        connector.registerParticipantEventListener(self)
        connector.reportLocalParticipant(onJoined: true)
        setupRemoteDevicesCallbackHandlers()
    }
    
    deinit {
        remoteCameraManager.unregisterRemoteCameraEventListener()
        remoteMicrophoneManager.unregisterRemoteMicrophoneEventListener()
        connector.unregisterParticipantEventListener()
    }
    
    func registerRemoteCamera() {
        remoteCameraManager.registerRemoteCameraEventListener()
    }
    
    func registerRemoteDevices() {
        remoteCameraManager.registerRemoteCameraEventListener()
        remoteMicrophoneManager.registerRemoteMicrophoneEventListener()
    }
    
    func unregisterRemoteCamera() {
        remoteCameraManager.unregisterRemoteCameraEventListener()
    }
    
    func pinPartisipant(_ participantID: String, pin: Bool) -> Bool {
        guard let participant = participants.first(where: { $0.getId() == participantID }) else {
           return false
        }
        return connector.pinParticipant(participant, pin: pin)
    }
    
    private func setupRemoteDevicesCallbackHandlers() {
        // Remote micro handlers
        remoteMicrophoneManager.onRemoteMicrophoneStateUpdatedHandler = { [weak self] (participant, state) in
            var isMicMuted = false
            if state == .paused || state == .removed { isMicMuted = true }
            self?.onParticipantMicrophoneStateUpdatedHandler?(participant.getId(), isMicMuted)
        }
        // Remote camera handlers
        remoteCameraManager.onRemoteCameraAddedHandler = { [weak self] (participant) in
            self?.onParticipantCameraAddedHandler?(participant.getId())
        }
        remoteCameraManager.onRemoteCameraStateUpdatedHandler = { [weak self] (participant, isControllable) in
            self?.onParticipantCameraStateUpdatedHandler?(participant.getId(), isControllable)
        }
        remoteCameraManager.onRemoteCameraRemovedHandler = { [weak self] (participant) in
            self?.onParticipantCameraRemovedHandler?(participant.getId())
        }
    }
    
    private func notify(_ name: Notification.Name, event: ChatNotificationEventType, participant: VCParticipant) {
        let notifacation = ChatNotification(participant: participant, event: event)
        let userInfo: [String : Any] = [UserInfoKey.participant: participant, UserInfoKey.notification: notifacation]
        DispatchQueue.global(qos: .userInteractive).async {
            guard event == .joinedConference else {
                NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
                return
            }
            // Pass ChatNotification info (for group chat) after a local participant joined
            if self.isLocalParticipantJoined {
                NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
            } else {
                self.isLocalParticipantJoined = participant.isLocal()
                NotificationCenter.default.post(name: name, object: nil, userInfo: [UserInfoKey.participant: participant])
            }
        }
    }
}

//MARK: - VCConnectorIRegisterParticipantEventListener
extension ParticipantsManager: VCConnectorIRegisterParticipantEventListener {
    func onParticipantJoined(_ participant: VCParticipant!) {
        guard let participant = participant else { return }
        participants.append(participant)
        notify(.participantJoinedConference, event: .joinedConference, participant: participant)
    }
    
    func onParticipantLeft(_ participant: VCParticipant!) {
        guard let participant = participant else { return }
        participants = participants.filter { $0 != participant}
        if participant.isLocal() { isLocalParticipantJoined = false }
        notify(.participantLeftConference, event: .leftConference, participant: participant)
    }
    
    func onDynamicParticipantChanged(_ participants: NSMutableArray!) {}
    
    func onLoudestParticipantChanged(_ participant: VCParticipant!, audioOnly: Bool) {}
}
