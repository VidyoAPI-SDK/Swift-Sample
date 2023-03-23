//
//  FrameRateTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 04.09.2021.
//

import UIKit

class FrameRateTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var logoView: UIView!
    @IBOutlet private weak var frameRateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear
        logoView.layer.cornerRadius = 10
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        accessoryType = .none
        frameRateLabel.text = nil
    }
    
    func configure(with model: FrameRateCellModel) {
        accessoryType = model.accessoryType
        frameRateLabel.text = model.type.rawValue
    }
}
