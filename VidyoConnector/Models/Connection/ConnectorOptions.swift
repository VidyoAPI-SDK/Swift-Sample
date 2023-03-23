//
//  ConnectorOptions.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 15.07.2021.
//

import Foundation

struct AutoReconnectSetting {
    let enableAutoReconnect: Bool
    let reconnectBackoff: UInt32
    let maxReconnectAttempts: UInt32
}

struct AudioSettingOptions: Decodable {
    let preferredAudioCodec: String
    let audioPacketInterval: Int
    let audioPacketLossPercentage: Int
    let audioBitrateMultiplier: Int
}
