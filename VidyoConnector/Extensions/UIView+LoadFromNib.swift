//
//  UIView+LoadFromNib.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 09.08.2021.
//

import UIKit

extension UIView {
    static var reuseIndentifier: String {
        return String(describing: self)
    }
    
    static var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: nil)
    }
    
    static func loadFromNib() -> Self {
        func instantiateUsingNib<T: UIView>() -> T {
            guard let view = nib.instantiate(withOwner: nil, options: nil).first as? T else {
                fatalError("Failed to load view \(String(describing: self)).")
            }
            return view
        }
        return instantiateUsingNib()
    }
}
