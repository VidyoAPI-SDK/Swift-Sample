//
//  AvatarView.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 11.08.2021.
//

import UIKit

class AvatarView: UIView {
    // MARK: - IBOutlets
    @IBOutlet weak private var paricipantView: UIView!
    @IBOutlet weak private var initialsLabel: UILabel!
    @IBOutlet weak private var avatarImageView: UIImageView!
    @IBOutlet weak private var newMessagesCountLabel: UILabel!
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        paricipantView.layer.cornerRadius = 20
        
        newMessagesCountLabel.clipsToBounds = true
        newMessagesCountLabel.layer.cornerRadius = 8
        
        newMessagesCountLabel.isHidden = true
    }
    
    // MARK: - Methods
    func setIntitials(_ initials: String) {
        initialsLabel.text = initials
        initialsLabel.isHidden = false
    }
    
    func showGroupChat() {
        initialsLabel.isHidden = true
        avatarImageView.isHidden = false
        avatarImageView.image = Constants.Chat.groupChatImage
    }
    
    func showMessagesCount(_ count: Int) {
        guard count != 0 else { return }
        let countString = count > 9 ? "9+" : String(count)
        newMessagesCountLabel.text = countString
        newMessagesCountLabel.isHidden = false
    }
    
    func makeNotActive() {
        paricipantView.layer.opacity = 0.5
    }
    
    func makeActive() {
        paricipantView.layer.opacity = 1
    }
    
    func clearImage() {
        avatarImageView.image = nil
    }
    
    func clearNewMessagesIcon() {
        newMessagesCountLabel.isHidden = true
    }
}
