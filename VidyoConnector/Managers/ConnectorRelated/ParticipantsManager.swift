//
//  ParticipantsManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 05.07.2021.
//

import Foundation
import VidyoClientIOS

class ParticipantsManager {
    let connector = ConnectorManager.shared.connector
    
    var remoteCameraManager = RemoteCameraManager()
    var remoteMicrophoneManager = RemoteMicrophoneManager()
    
    var participants = SynchronizedArray<VCParticipant>()
    var isLocalParticipantJoined = false
    // MARK: System PiP support
    /// Latest loudest remote speaker from `onLoudestParticipantChanged` — PiP focus fallback after pin.
    private(set) var loudestParticipantId: String?

    var onParticipantMicrophoneStateUpdatedHandler: ((String, Bool) -> ())?
    var onParticipantCameraStateUpdatedHandler: ((String, Bool) -> ())?
    var onParticipantCameraAddedHandler: ((String) -> ())?
    var onParticipantCameraRemovedHandler: ((String) -> ())?

    private let changeLock = NSLock()
    /// Observers notified when loudest speaker changes (used by `ConferencePiPDataSource`).
    private var loudestObservers: [UUID: () -> Void] = [:]
    /// Observers notified when the roster changes (used by `ConferencePiPDataSource`).
    private var participantsObservers: [UUID: () -> Void] = [:]
    
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
        // Intentionally a no-op for System PiP: VCConnector has only one remote-camera
        // listener slot. Closing the participants sheet must not unregister it, or PiP
        // (and PTZ) lose camera add/remove/state updates for the rest of the call.
    }

    /// Used by `ConferencePiPDataSource` when loudest speaker changes.
    @discardableResult
    func addLoudestChangeObserver(_ handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        changeLock.lock()
        loudestObservers[id] = handler
        changeLock.unlock()
        return id
    }

    func removeLoudestChangeObserver(_ id: UUID) {
        changeLock.lock()
        loudestObservers.removeValue(forKey: id)
        changeLock.unlock()
    }

    /// Used by `ConferencePiPDataSource` when join/leave changes who PiP can focus.
    @discardableResult
    func addParticipantsChangeObserver(_ handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        changeLock.lock()
        participantsObservers[id] = handler
        changeLock.unlock()
        return id
    }

    func removeParticipantsChangeObserver(_ id: UUID) {
        changeLock.lock()
        participantsObservers.removeValue(forKey: id)
        changeLock.unlock()
    }

    private func notifyLoudestObservers() {
        changeLock.lock()
        let handlers = Array(loudestObservers.values)
        changeLock.unlock()
        DispatchQueue.main.async {
            handlers.forEach { $0() }
        }
    }

    private func notifyParticipantsObservers() {
        changeLock.lock()
        let handlers = Array(participantsObservers.values)
        changeLock.unlock()
        DispatchQueue.main.async {
            handlers.forEach { $0() }
        }
    }
    
    func pinParticipant(_ participant: VCParticipant, _ pin: Bool, _ callback: @escaping (Bool) -> Void) {
        RendererManager.shared.pinParticipant(participant, pin, callback)
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
        notifyParticipantsObservers()
        notify(.participantJoinedConference, event: .joinedConference, participant: participant)
    }
    
    func onParticipantLeft(_ participant: VCParticipant!) {
        guard let participant = participant else { return }
        participants = participants.filter { $0 != participant}
        if participant.isLocal() { isLocalParticipantJoined = false }
        if loudestParticipantId == participant.getId() {
            loudestParticipantId = nil
            notifyLoudestObservers()
        }
        notifyParticipantsObservers()
        notify(.participantLeftConference, event: .leftConference, participant: participant)
    }
    
    func onDynamicParticipantChanged(_ participants: NSMutableArray!) {}
    
    func onLoudestParticipantChanged(_ participant: VCParticipant!, audioOnly: Bool) {
        // Feed System PiP focus (priority after share + pin).
        let newId = participant?.getId()
        guard loudestParticipantId != newId else { return }
        loudestParticipantId = newId
        notifyLoudestObservers()
    }
}
