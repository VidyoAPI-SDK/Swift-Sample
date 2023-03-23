//
//  UIViewController+GestureRecognizer.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 24.05.2021.
//

import UIKit

extension UIViewController {
    func addTapGestureRecognizerForKeyboardHiding() {
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(hideKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func hideKeyboard() {
        view.endEditing(true)
    }
}
