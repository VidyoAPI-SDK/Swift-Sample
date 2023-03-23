//
//  SettingsTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 09.06.2021.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {

    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var optionLabel: UILabel!
    
    override func prepareForReuse() {
        iconView.image = nil
        optionLabel.text = nil
    }
    
    func configure(with cellModel: SettingsOptionCell) {
        iconView.image = UIImage(named: cellModel.iconName)
        optionLabel.text = cellModel.title.rawValue
        isUserInteractionEnabled = cellModel.isEnabled
        
        guard !cellModel.isEnabled else { return }
        optionLabel?.textColor = .lightGray
    }
}
