//
//  DeviceState.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 15.09.2021.
//

import Foundation

enum DeviceState {
    case muted
    case unmuted
    case disabled
    
    var bool: Bool {
        guard self == .unmuted else { return true }
        return false
    }
    
    mutating func setState(_ state: DeviceState) {
        self = state
    }
    
    mutating func swapBasicStates() {
        switch self {
        case .muted: self = .unmuted
        case .unmuted: self = .muted
        default: break
        }
    }
    
    mutating func enableIfNeeded() {
        if self == .disabled {
            self =  .muted
        }
    }
}
