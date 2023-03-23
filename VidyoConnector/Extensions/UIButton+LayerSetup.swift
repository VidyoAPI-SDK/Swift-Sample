//
//  UIButton+LayerSetup.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 24.05.2021.
//

import UIKit

extension UIButton {
    func setup() {
        isEnabled = false
        layer.opacity = 0.5
        layer.cornerRadius = 4
    }
    
    func setOpacity() {
        layer.opacity = 0.5
    }
    
    func enable() {
        layer.opacity = 1
        isEnabled = true
    }
    
    func disable() {
        layer.opacity = 0.5
        isEnabled = false
    }
}
