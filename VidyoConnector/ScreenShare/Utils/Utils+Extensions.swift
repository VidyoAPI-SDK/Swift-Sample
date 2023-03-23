//
//  Utils+Extensions.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 30.07.2021.
//

import Foundation

extension CGSize {
    func capped(at resolution: CGFloat) -> CGSize {
        let minSide = min(width, height)
        guard resolution < minSide else { return self }
        let k = resolution / minSide
        return CGSize(width: Int(width * k), height: Int(height * k))
    }
}

extension UIWindow {
    func absoluteFrame() -> CGRect {
        return convert(frame, to: screen.coordinateSpace)
    }
}
