//
//  SentMessageTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 15.08.2021.
//

import UIKit

class SentMessageTableViewCell: UITableViewCell, MessageTableViewCellProtocol {

    @IBOutlet weak var bubbleMessageView: UIView!
    @IBOutlet weak var bubbleImageView: UIImageView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    let msgImage = UIImage(named: Constants.Icon.sendBubble)
    let imgInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    
    override func awakeFromNib() {
        super.awakeFromNib()
        bubbleMessageView.layer.cornerRadius = 5
        bubbleImageView.image = msgImage?.resizableImage(withCapInsets: imgInsets, resizingMode: .stretch)
    }
    
    override func prepareForReuse() {
        messageLabel.text = nil
        timeLabel.text = nil
    }
    
    func configure(with model: MessageProtocol) {
        messageLabel.text = model.text
        timeLabel.text = model.time
    }
}
