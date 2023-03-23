//
//  UIViewController+Observation.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 21.08.2021.
//

import Foundation

extension UIViewController {
    func observe(_ name: NSNotification.Name?, _ selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
    }
    
    func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
}
