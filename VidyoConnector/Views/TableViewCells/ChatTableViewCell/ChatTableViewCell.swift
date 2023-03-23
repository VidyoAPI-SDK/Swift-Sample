//
//  ChatTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 11.08.2021.
//

import UIKit

class ChatTableViewCell: UITableViewCell {

    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var leftConferenceLabel: UILabel!
    
    let avatar = AvatarView.loadFromNib()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        addAvatar()
        avatarView.backgroundColor = .clear
        leftConferenceLabel.isHidden = true
    }
    
    override func prepareForReuse() {
        avatar.makeActive()
        avatar.clearImage()
        avatar.clearNewMessagesIcon()
        avatarView.backgroundColor = .clear
        displayNameLabel.textColor = .white
        displayNameLabel.text = nil
        leftConferenceLabel.isHidden = true
    }
    
    func configure(with model: Chat) {
        displayNameLabel.text = model.name
        leftConferenceLabel.isHidden = model.isActive        
        avatar.showMessagesCount(model.newMessageCount)
        
        if !model.isActive {
            displayNameLabel.textColor = .lightGray
            avatar.makeNotActive()
        }
        
        guard !model.isGroupChat else {
            avatar.showGroupChat()
            return
        }
        avatar.setIntitials(model.avatarInitials)
    }
    
    func addAvatar() {
        avatarView.addSubview(avatar)
        avatar.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor).isActive = true
        avatar.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor).isActive = true
    }
}
