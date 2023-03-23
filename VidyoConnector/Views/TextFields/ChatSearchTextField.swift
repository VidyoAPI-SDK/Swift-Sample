//
//  ChatSearchTextField.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 12.08.2021.
//

import Foundation

class ChatSearchTextField: UITextField {
    
    var textPadding = UIEdgeInsets(
        top: 0,
        left: 15,
        bottom: 0,
        right: 15
    )
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        layer.cornerRadius = 4
        backgroundColor = .darkGray
        textColor = .white
        
        clearButtonMode = .whileEditing
        attributedPlaceholder = NSAttributedString(
            string: "Type participant name",
            attributes: [NSAttributedString.Key.foregroundColor : UIColor.gray]
        )
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.textRect(forBounds: bounds)
        return rect.inset(by: textPadding)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.editingRect(forBounds: bounds)
        return rect.inset(by: textPadding)
    }
}
