//
//  NetworkManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 25.06.2021.
//

import Foundation

class NetworkInterfaceManager {
    let connector = ConnectorManager.shared.connector
    
    var networkInterfaces = SynchronizedArray<VCNetworkInterface>()
    var currentNetworkSignaling: VCNetworkInterface?
    var currentNetworkMedia: VCNetworkInterface?
    
    var isNetworkInterfacesAvailableForSelecting: Bool {
        networkInterfaces.count > 1
    }

    init() {
        connector.getActiveNetworkInterface(self)
        connector.registerNetworkInterfaceEventListener(self)
    }
    
    deinit {
        connector.unregisterNetworkInterfaceEventListener()
    }
    
    func setNetworkForSignaling(networkNumber: Int) -> Bool {
        guard networkNumber < networkInterfaces.count else { return false }
        currentNetworkSignaling = networkInterfaces[networkNumber]
        return connector.selectNetworkInterface(forSignaling: currentNetworkSignaling)
    }
    
    func setNetworkForMedia(networkNumber: Int) -> Bool {
        guard networkNumber < networkInterfaces.count else { return false }
        currentNetworkMedia = networkInterfaces[networkNumber]
        return connector.selectNetworkInterface(forMedia: currentNetworkMedia)
    }
    
    func removeNetworkInterface(_ networkInterface: VCNetworkInterface) {
        networkInterfaces = networkInterfaces.filter { $0 != networkInterface }
        
        if currentNetworkSignaling == networkInterface {
            currentNetworkSignaling = networkInterfaces.first
            connector.selectNetworkInterface(forSignaling: currentNetworkSignaling)
        } else if currentNetworkMedia == networkInterface {
            currentNetworkMedia = networkInterfaces.first
            connector.selectNetworkInterface(forMedia: currentNetworkMedia)
        }
    }
}

//MARK: - VCConnectorIRegisterNetworkInterfaceEventListener
extension NetworkInterfaceManager: VCConnectorIRegisterNetworkInterfaceEventListener {
    func onNetworkInterfaceAdded(_ networkInterface: VCNetworkInterface!) {
        networkInterfaces.append(networkInterface)
    }
    
    func onNetworkInterfaceRemoved(_ networkInterface: VCNetworkInterface!) {
        removeNetworkInterface(networkInterface)
    }
    
    func onNetworkInterfaceSelected(_ networkInterface: VCNetworkInterface!, transportType: VCNetworkInterfaceTransportType) {}
    
    func onNetworkInterfaceStateUpdated(_ networkInterface: VCNetworkInterface!, state: VCNetworkInterfaceState) {}
}

//MARK: - VCConnectorIGetActiveNetworkInterface
extension NetworkInterfaceManager: VCConnectorIGetActiveNetworkInterface {
    func onGetActiveNetworkInterface(_ signalingInterface: VCNetworkInterface!, mediaInterface: VCNetworkInterface!) {
        if networkInterfaces.isEmpty {
            currentNetworkSignaling = signalingInterface
            currentNetworkMedia = mediaInterface
            networkInterfaces.append(signalingInterface)
            networkInterfaces.append(mediaInterface)
        }
    }
}
