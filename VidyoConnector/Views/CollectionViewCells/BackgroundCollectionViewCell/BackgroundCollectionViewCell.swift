//
//  BackgroundCollectionViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 27.08.2021.
//

import UIKit

class BackgroundCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var checkmarkImageView: UIImageView!
    @IBOutlet weak var backgroungImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 4
        checkmarkImageView.layer.cornerRadius = 8
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        checkmarkImageView.isHidden = true
        backgroungImageView.image = nil
        descriptionLabel.text = nil
        layer.borderColor = UIColor.white.cgColor
        backgroungImageView.contentMode = .scaleAspectFill
    }
    
    func configure(with model: BackgroundModel) {
        descriptionLabel.text = model.title
        backgroungImageView.image = model.image
        checkmarkImageView.isHidden = !model.isSelected
        if model.type == .none {
            backgroungImageView.contentMode = .scaleToFill
        }
        guard model.type == .none || (model.type == .photo && model.image == nil) else { return }
        layer.borderColor = UIColor.gray.cgColor
        layer.borderWidth = 1
    }
}
