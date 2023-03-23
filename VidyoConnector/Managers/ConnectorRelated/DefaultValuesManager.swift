//
//  DefaultValuesManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 14.07.2021.
//

import Foundation

class DefaultValuesManager {
    static let shared = DefaultValuesManager()
    
    private var autoReconnectSetting: AutoReconnectSetting?
    private var audioOptions: AudioSettingOptions?
    
    private init() {}
    
    func getCPUProfile() -> VCConnectorTradeOffProfile {
        ConnectorManager.shared.connector.getCpuTradeOffProfile()
    }
    
    func getAutoReconnectSetting() -> AutoReconnectSetting? {
        ConnectorManager.shared.connector.getAutoReconnectSetting(self)
        return autoReconnectSetting
    }
    
    func getAudioOptions() -> AudioSettingOptions? {
        guard
            let jsonString = ConnectorManager.shared.connector.getOptions(),
            let json = jsonString.data(using: .utf8)
        else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromUpperCamelCase
        
        if let jsonPetitions = try? decoder.decode(AudioSettingOptions.self, from: json) {
            audioOptions = jsonPetitions
        }
        return audioOptions
    }
    
    func getMaxSendBitRateBps() -> UInt32 {
        ConnectorManager.shared.connector.getMaxSendBitRate()
    }
    
    func getMaxReceiveBitRateBps() -> UInt32 {
        ConnectorManager.shared.connector.getMaxReceiveBitRate()
    }
    
    func getLogLevel() -> VCConnectorLogLevel {
        ConnectorManager.shared.connector.getLogLevel(.CONSOLE)
    }
}

//MARK: - VCConnectorIGetAutoReconnectSetting
extension DefaultValuesManager: VCConnectorIGetAutoReconnectSetting {
    func onGetAutoReconnectSetting(_ enableAutoReconnect: Bool, reconnectBackoff: UInt32, maxReconnectAttempts: UInt32) {
        autoReconnectSetting = AutoReconnectSetting(
            enableAutoReconnect: enableAutoReconnect,
            reconnectBackoff: reconnectBackoff,
            maxReconnectAttempts: maxReconnectAttempts
        )
    }
}
