//
//  ConnectionState.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 14.07.2021.
//

import Foundation

enum ConnectionState {
    case connected
    case disconnected
    
    var bool: Bool {
        guard self == .connected else { return false }
        return true
    }
}
