//
//  JsonKeyDecodingStrategy+UpperCamelCase.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 15.07.2021.
//

import Foundation

struct UpperCamelCaseCodingKey: CodingKey {
    static let empty = UpperCamelCaseCodingKey(stringValue: "")
    
    var stringValue: String
    var intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension JSONDecoder.KeyDecodingStrategy {
    static let convertFromUpperCamelCase = JSONDecoder.KeyDecodingStrategy.custom({ keys in
        guard let lastKey = keys.last else {
            return UpperCamelCaseCodingKey.empty
        }
        if lastKey.intValue != nil {
            return lastKey
        }
        guard let firstLetter = lastKey.stringValue.first?.lowercased() else {
            return lastKey
        }
        let lowerCamelCaseKey = firstLetter + lastKey.stringValue.dropFirst()
        return UpperCamelCaseCodingKey(stringValue: lowerCamelCaseKey)
    })
}
