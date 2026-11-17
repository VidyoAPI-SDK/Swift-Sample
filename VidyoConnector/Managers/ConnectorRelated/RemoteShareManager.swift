//
//  RemoteShareManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.08.2021.
//

import Foundation
import VidyoClientIOS

class RemoteShareManager {
    let connector = ConnectorManager.shared.connector
    // MARK: System PiP support — remote share is highest PiP focus priority.
    private var remoteShares = SynchronizedArray<PiPRemoteShareRow>()
    private let changeLock = NSLock()
    private var changeObservers: [UUID: () -> Void] = [:]
    
    init() {
        connector.registerRemoteWindowShareEventListener(self)
    }
    
    deinit {
        connector.unregisterRemoteWindowShareEventListener()
    }

    /// Thread-safe copy for `PiPCallDataSource.remoteShareSnapshot()`.
    func synchronizedSnapshot() -> [PiPRemoteShareRow] {
        remoteShares.map { $0 }
    }

    /// Used by `ConferencePiPDataSource` so PiP switches to share when one appears.
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
    
    func notify(_ notificationName: Notification.Name, event: ChatNotificationEventType, participant: VCParticipant) {
        DispatchQueue.global(qos: .userInteractive).async {
            let notification = ChatNotification(participant: participant, event: event)
            NotificationCenter.default.post(
                name: notificationName,
                object: nil,
                userInfo: [UserInfoKey.notification: notification]
            )
        }
    }
}

//MARK: - VCConnectorIRegisterRemoteWindowShareEventListener
extension RemoteShareManager: VCConnectorIRegisterRemoteWindowShareEventListener {
    func onRemoteWindowShareAdded(_ remoteWindowShare: VCRemoteWindowShare!, participant: VCParticipant!) {
        guard let remoteWindowShare = remoteWindowShare, let participant = participant else { return }
        if remoteShares.firstIndex(where: { $0.share === remoteWindowShare }) == nil {
            remoteShares.append(PiPRemoteShareRow(share: remoteWindowShare, participant: participant))
            notifyChangeObservers()
        }
        notify(.remoteShareStarted, event: .startedSharing, participant: participant)
    }
    
    func onRemoteWindowShareRemoved(_ remoteWindowShare: VCRemoteWindowShare!, participant: VCParticipant!) {
        if let remoteWindowShare = remoteWindowShare {
            remoteShares.remove(where: { $0.share === remoteWindowShare })
            notifyChangeObservers()
        }
        if let participant = participant {
            notify(.remoteShareFinished, event: .stoppedSharing, participant: participant)
        }
    }
    
    func onRemoteWindowShareStateUpdated(_ remoteWindowShare: VCRemoteWindowShare!, participant: VCParticipant!, state: VCDeviceState) {}
}
