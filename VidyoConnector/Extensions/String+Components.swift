//
//  String+Components.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 28.06.2021.
//

import Foundation

extension String {
    var letters: String {
        components(separatedBy: CharacterSet.letters.inverted).joined()
    }
    
    var digits: String {
        components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
        
    var resolution: (width: UInt32, height: UInt32)? {
        let stringArray = self.components(separatedBy: " x ")
        let uint32Array = stringArray.map { UInt32($0) }
        guard
            let width = uint32Array[0],
            let height = uint32Array[1]
        else { return nil }
        return (width, height)
    }
    
    var toBtsInUInt32: UInt32? {
        guard let MBts = Double(self) else { return nil }
        guard UInt64(MBts * 1e+6) <= UInt32.max else { return nil }
        return UInt32(MBts * 1e+6)
	}
    
    var withoutWhitespaces: String {
        replacingOccurrences(of: " ", with: "", options: NSString.CompareOptions.literal, range: nil)
    }
    
    var initials: String {
        var words = trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
        words = words.filter { $0.withoutWhitespaces != "" }
        if words.count > 2 { words.removeSubrange(2...) }
        return words.compactMap({ $0.isEmpty ? nil : $0.first?.uppercased() }).joined()
    }
}
