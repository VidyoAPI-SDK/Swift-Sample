//
//  MessageProtocol.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 17.08.2021.
//

import Foundation

enum MessageType {
    case message
    case notification
}

protocol MessageProtocol {
    var type: MessageType { get }
    var text: String { get }
    var date: Date { get }
    var time: String { get }
}

extension MessageProtocol {
    var time: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        return dateFormatter.string(from: self.date)
    }
}
