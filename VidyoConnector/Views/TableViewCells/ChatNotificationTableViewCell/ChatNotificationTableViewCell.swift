//
//  ChatNotificationTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.08.2021.
//

import UIKit

protocol MessageTableViewCellProtocol: UITableViewCell {
    func configure(with model: MessageProtocol)
}

class ChatNotificationTableViewCell: UITableViewCell, MessageTableViewCellProtocol {
    
    @IBOutlet weak var notificationLabel: UILabel!
    
    func configure(with model: MessageProtocol) {
        notificationLabel.text = model.text
    }
}
