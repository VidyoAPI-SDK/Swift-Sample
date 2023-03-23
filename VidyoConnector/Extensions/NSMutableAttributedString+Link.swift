//
//  NSMutableAttributedString+Link.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 03.09.2021.
//

import Foundation

extension NSMutableAttributedString {
    static let linkTextAttributes: [NSAttributedString.Key : Any] = [
        NSAttributedString.Key.foregroundColor: UIColor.blue,
        NSAttributedString.Key.underlineColor: UIColor.blue,
        NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue
    ]
    
    func setFirstOccurrenceTextAsLink(_ link: String, text: String) {
        guard link.isURL, link.canOpenURL else { return }
        let textRange = mutableString.range(of: text)
        addAttribute(.link, value: link, range: textRange)
    }
}
