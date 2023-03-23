//
//  UInt32+DataConverting.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 04.07.2021.
//

import Foundation

extension UInt32 {
    var ordinalString: String? {
        let ordinalFormatter = NumberFormatter()
        ordinalFormatter.numberStyle = .ordinal
        return ordinalFormatter.string(from: NSNumber(value: self))
    }
}
