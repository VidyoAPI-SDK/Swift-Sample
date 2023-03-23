//
//  MainOptionTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 09.06.2021.
//

import UIKit

class MainOptionTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var optionLabel: UILabel!
    
    override func prepareForReuse() {
        titleLabel.text = nil
        optionLabel.text = nil
    }
    
    func configure(with cellModel: ChooseOptionCell) {
        titleLabel.text = cellModel.title
        optionLabel.text = cellModel.getChosenOptionTitle()
        isUserInteractionEnabled = cellModel.isEnabled
        
        guard !cellModel.isEnabled else { return }
        titleLabel.textColor = .lightGray
        optionLabel?.textColor = .lightGray
    }
}
