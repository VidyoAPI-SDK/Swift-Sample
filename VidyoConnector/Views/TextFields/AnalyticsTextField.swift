//
//  AnalyticsTextField.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.06.2021.
//

import Foundation

class AnalyticsTextField: UITextField {
    
    var textPadding = UIEdgeInsets(
        top: 0,
        left: 15,
        bottom: 0,
        right: 15
    )
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        layer.borderWidth = 1.0
        layer.cornerRadius = 4
        layer.borderColor = Constants.Color.analyticsTextFieldBorder
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
