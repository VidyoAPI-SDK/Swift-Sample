//
//  RemoteMicrophoneManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 05.07.2021.
//

import Foundation
import VidyoClientIOS

class RemoteMicrophoneManager {
    let connector = ConnectorManager.shared.connector
    
    var onRemoteMicrophoneStateUpdatedHandler: ((VCParticipant, VCDeviceState) -> ())?

    // MARK: System PiP support — mic on/off drives the speaking ring on the initials placeholder.
    private var micOnByUserId: [String: Bool] = [:]
    private let stateLock = NSLock()
    private let changeLock = NSLock()
    private var changeObservers: [UUID: () -> Void] = [:]
    
    func registerRemoteMicrophoneEventListener() {
        connector.registerRemoteMicrophoneEventListener(self)
    }
    
    func unregisterRemoteMicrophoneEventListener() {
        connector.unregisterRemoteMicrophoneEventListener()
    }

    /// Used by `PiPCallDataSource.isRemoteMicOn(userId:)`.
    func isMicOn(for userId: String) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return micOnByUserId[userId] ?? false
    }

    /// Used by `ConferencePiPDataSource` so the PiP placeholder updates when mic state changes.
    @discardableResult
    func addChangeObserver(_ handler: @escaping () -> Void) -> UUID {
        let id = UUID()
        changeLock.lock()
        changeObservers[id] = handler
        changeLock.unlock()
        return id
    }

    func removeChangeObserver(_ id: UUID) {
        changeLock.lock()
        changeObservers.removeValue(forKey: id)
        changeLock.unlock()
    }

    private func notifyChangeObservers() {
        changeLock.lock()
        let handlers = Array(changeObservers.values)
        changeLock.unlock()
        DispatchQueue.main.async {
            handlers.forEach { $0() }
        }
    }

    private func setMicOn(_ on: Bool, for participant: VCParticipant?) {
        guard let userId = participant?.getId(), !userId.isEmpty else { return }
        stateLock.lock()
        micOnByUserId[userId] = on
        stateLock.unlock()
        notifyChangeObservers()
    }

    private func isMicOnState(_ state: VCDeviceState) -> Bool {
        switch state {
        case .paused, .stopped, .suspended, .removed:
            return false
        default:
            return true
        }
    }
}

//MARK: - VCConnectorIRegisterRemoteMicrophoneEventListener
extension RemoteMicrophoneManager: VCConnectorIRegisterRemoteMicrophoneEventListener {
    func onRemoteMicrophoneAdded(_ remoteMicrophone: VCRemoteMicrophone!, participant: VCParticipant!) {
        setMicOn(true, for: participant)
        onRemoteMicrophoneStateUpdatedHandler?(participant, .added)
    }
    
    func onRemoteMicrophoneRemoved(_ remoteMicrophone: VCRemoteMicrophone!, participant: VCParticipant!) {
        setMicOn(false, for: participant)
        onRemoteMicrophoneStateUpdatedHandler?(participant, .removed)
    }
    
    func onRemoteMicrophoneStateUpdated(_ remoteMicrophone: VCRemoteMicrophone!, participant: VCParticipant!, state: VCDeviceState) {
        setMicOn(isMicOnState(state), for: participant)
        onRemoteMicrophoneStateUpdatedHandler?(participant, state)
    }
}
