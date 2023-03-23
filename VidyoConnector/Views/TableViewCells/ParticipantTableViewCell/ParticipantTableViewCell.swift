//
//  ParticipantTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 05.07.2021.
//

import UIKit

class ParticipantTableViewCell: UITableViewCell {

    @IBOutlet weak var paricipantImageView: UIView!
    @IBOutlet weak var initialsLabel: UILabel!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var micStatusImageView: UIImageView!
    @IBOutlet weak var cameraStatusImageView: UIImageView!
    @IBOutlet weak var participantTypeLabel: UILabel!
    @IBOutlet weak var feccIcon: UIImageView!
    @IBOutlet weak var pinButton: UIButton!
    
    var pinParticipantHandler: (() -> ())?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        paricipantImageView.layer.cornerRadius = 20
    }
    
    @IBAction func pinButtonPressed(_ sender: UIButton) {
        pinParticipantHandler?()
    }
    
    override func prepareForReuse() {
        initialsLabel.text = nil
        displayNameLabel.text = nil
        participantTypeLabel.text = nil
        
        micStatusImageView.isHidden = false
        cameraStatusImageView.isHidden = false
        feccIcon.isHidden = true
        pinButton.isHidden = true
    }
    
    func configure(with model: Participant) {
        initialsLabel.text = model.name.initials
        displayNameLabel.text = model.name
        participantTypeLabel.text = model.type
        
        micStatusImageView.isHidden = !model.isMicMuted
        cameraStatusImageView.isHidden = !model.isCameraMuted
        feccIcon.isHidden = !model.isCameraControllable
        pinButton.isHidden = model.isCameraMuted
        
        handlePin(forParticipant: model)
        guard model.isCameraMuted else { return }
        pinButton.tintColor = UIColor.white
    }
    
    func handlePin(forParticipant participant: Participant) {
        if participant.isLocal { pinButton.isHidden = true }
        if participant.isPinned {
            pinButton.tintColor = UIColor(named: "PinnedUserColor")
        } else {
            pinButton.tintColor = UIColor.white
        }
    }
}
