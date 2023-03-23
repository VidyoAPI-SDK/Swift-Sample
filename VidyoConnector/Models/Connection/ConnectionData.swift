//
//  ConnectionData.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 28.05.2021.
//

import Foundation

protocol ConnectionData {
    var portalAddress: String { get set }
    var roomKey: String { get set }
    var roomPin: String { get set }
}

struct GuestData: ConnectionData {
    var portalAddress: String
    var displayName: String
    var roomKey: String
    var roomPin: String
}

struct UserData: ConnectionData {
    var portalAddress: String
    var username: String
    var password: String
    var roomKey: String
    var roomPin: String
}
