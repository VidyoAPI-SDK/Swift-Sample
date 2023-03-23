//
//  ReceivedMessageTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 15.08.2021.
//

import UIKit

class ReceivedMessageTableViewCell: UITableViewCell, MessageTableViewCellProtocol {

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var senderNameLabel: UILabel!
    @IBOutlet weak var bubbleMessageView: UIView!
    @IBOutlet weak var bubbleImageView: UIImageView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    let avatar = AvatarView.loadFromNib()
    let msgImage = UIImage(named: Constants.Icon.receiveBubble)
    let imgInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    
    override func awakeFromNib() {
        super.awakeFromNib()
        addAvatar()
        avatarView.backgroundColor = .clear
        bubbleMessageView.layer.cornerRadius = 5
        bubbleImageView.image = msgImage?.resizableImage(withCapInsets: imgInsets, resizingMode: .stretch)
    }
    
    override func prepareForReuse() {
        avatar.clearImage()
        senderNameLabel.text = nil
        messageLabel.text = nil
        timeLabel.text = nil
    }
    
    func configure(with model: MessageProtocol) {
        guard let model = model as? Message else { return }
        avatar.setIntitials(model.senderName.initials)
        senderNameLabel.text = model.senderName
        messageLabel.text = model.text
        timeLabel.text = model.time
    }
    
    func addAvatar() {
        avatarView.addSubview(avatar)
        avatar.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor).isActive = true
        avatar.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor).isActive = true
    }
}
