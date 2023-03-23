//
//  LoginTextField.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 24.05.2021.
//

import UIKit

class LoginTextField: UITextField {
    
    var textPadding = UIEdgeInsets(
        top: 0,
        left: 10,
        bottom: 0,
        right: 10
    )
    
    var isNotEmpty: Bool {
        let textWithoutWhitespaces = text?.replacingOccurrences(
            of: " ", with: "",
            options: NSString.CompareOptions.literal,
            range: nil
        )
        return textWithoutWhitespaces != ""
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        updateState()
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.textRect(forBounds: bounds)
        return rect.inset(by: textPadding)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.editingRect(forBounds: bounds)
        return rect.inset(by: textPadding)
    }
    
    func updateState() {
        guard isNotEmpty else {
            setInactive()
            return
        }
        setActive()
    }
    
    func setActive() {
        setPlaceholderColor(.white)
        backgroundColor = UIColor(named: "ActiveTextFieldColor")
    }
    
    private func setInactive() {
        setPlaceholderColor(.lightGray)
        backgroundColor = UIColor(named: "InactiveTextFieldColor")
    }
    
    private func setPlaceholderColor(_ color: UIColor) {
        if let placeholderText = placeholder {
            attributedPlaceholder = NSAttributedString(
                string: placeholderText,
                attributes: [NSAttributedString.Key.foregroundColor: color]
            )
        }
    }
}
