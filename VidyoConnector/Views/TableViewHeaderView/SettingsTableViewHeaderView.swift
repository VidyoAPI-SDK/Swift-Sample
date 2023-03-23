//
//  SettingsTableViewHeaderView.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.06.2021.
//

import UIKit

class SettingsTableViewHeaderView: UITableViewHeaderFooterView {
  
    let label = UILabel()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        backgroundView = UIView(frame: bounds)
        backgroundView?.backgroundColor = Constants.Color.settingsHeaderBackground
        
        setupLabel()
        addSubview(label)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        fatalError("required init?(coder:) has not been implemented")
    }
    
    private func setupLabel() {
        label.frame = CGRect(x: 25, y: 12, width: frame.width - 10, height: frame.height - 10)
        label.font = .systemFont(ofSize: 14)
        label.textColor = .darkGray
    }
    
    func configure(with text: String) {
        label.text = text
    }
}
