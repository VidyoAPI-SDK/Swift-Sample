//
//  LogLevelOptions.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 13.07.2021.
//

import Foundation

struct LogLevelOptions {
    static var options: [OptionToChoose] = {
        var options = [
            OptionToChoose(logLevel: .debug),
            OptionToChoose(logLevel: .production),
            OptionToChoose(logLevel: .advanced)
        ]
        let logLevel = DefaultValuesManager.shared.getLogLevel()
        switch logLevel{
        case .DEBUG:
            options[0].isChosen = true
        case .PRODUCTION:
            options[1].isChosen = true
        default:
            return options
        }
        return options
    }()
    
    static func getCurrentLogLevel() -> String {
        var title = String()
        options.forEach {
            if $0.isChosen {
                title = $0.title
            }
        }
        return title
    }
}
