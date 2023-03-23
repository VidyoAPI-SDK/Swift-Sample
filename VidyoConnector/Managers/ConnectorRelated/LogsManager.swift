//
//  LogsManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 08.07.2021.
//

import Foundation

class LogsManager {
    let connector = ConnectorManager.shared.connector
    
    private func setLogLevel(logLevel: VCConnectorLogLevel) -> Bool {
        return connector.setLogLevel(.FILE, logLevel: logLevel)
    }
    
    func setAdvancedLogOptions(filter: NSMutableString) -> Bool {
        return connector.setAdvancedLogOptions(.FILE, advancedLogFilter: filter)
    }
    
    func setLogLevel(_ logLevel: LogLevel) -> Bool {
        switch logLevel {
        case .debug:
            return setLogLevel(logLevel: .DEBUG)
        case .production:
            return setLogLevel(logLevel: .PRODUCTION)
        case .advanced:
            return setAdvancedLogOptions(filter: "")
        }
    }
    
    func getLogsFromFile() -> String? {
        var logs: String?
        let fileURL = URL(fileURLWithPath: Constants.LogsFile.name, relativeTo: Constants.LogsFile.pathUrl)
        do {
            let savedData = try Data(contentsOf: fileURL)
            if let savedString = String(data: savedData, encoding: .utf8) {
                logs = savedString
            }
        } catch {
            log.error("Unable to read logs from the file")
        }
        return logs
    }
}
