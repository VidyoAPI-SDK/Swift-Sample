//
//  String+Validation.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 04.07.2021.
//

import Foundation

extension String {
    var isURL: Bool {
        let urlPattern = "((?:http|https)://)?(?:www\\.)?[\\w\\d\\-_]+\\.\\w{2,3}(\\.\\w{2})?(/(?<=/)(?:[\\w\\d\\-./_]+)?)?"
        return self.matches(pattern: urlPattern)
    }
    
    var canOpenURL: Bool {
        guard let url =  URL(string: self) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }
    
    var isIpAddress: Bool {
        return self.isIPv6 || self.isIPv4
    }
    
    private var isIPv4: Bool {
        var sin = sockaddr_in()
        return self.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1
    }

    private var isIPv6: Bool {
        var sin6 = sockaddr_in6()
        return self.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1
    }
    
    private func matches(pattern: String) -> Bool {
        var regex: NSRegularExpression?
        do {
            regex = try NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            )
        } catch {
            log.error("\(error.localizedDescription)")
            return false
        }
        
        return regex?.firstMatch(
            in: self,
            options: [],
            range: NSRange(location: 0, length: utf16.count)) != nil
    }
}
