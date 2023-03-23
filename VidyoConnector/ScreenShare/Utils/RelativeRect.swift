//
//  RelativeRect.swift
//  BroadcastExtension
//
//  Created by Marta Korol on 25.07.2021.
//

import UIKit

struct RelativeRect {
    enum ValidationError: Error {
        case InvalidArgs
    }
    
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    static var completeRect: RelativeRect {
        get { return try! RelativeRect(x: 0, y: 0, width: 1, height: 1) }
    }
    
    // MARK: - Initialisation
    init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) throws {
        guard RelativeRect.validArg(x)
            && RelativeRect.validArg(y)
            && RelativeRect.validArg(width)
            && RelativeRect.validArg(height) else {
                throw ValidationError.InvalidArgs
        }
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    // MARK: - Methods
    func cropRect(_ rect: CGRect) -> CGRect {
        let nx = rect.origin.x + round(rect.size.width * self.x)
        let ny = rect.origin.y + round(rect.size.height * self.y)
        let nw = round(rect.size.width * self.width)
        let nh = round(rect.size.height * self.height)
        
        return CGRect(x: nx, y: ny, width: nw, height: nh)
    }
    
    private static func validArg(_ value: CGFloat) -> Bool {
        return value >= 0.0 && value <= 1.0
    }
}
