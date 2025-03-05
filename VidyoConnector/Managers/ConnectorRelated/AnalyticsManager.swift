//
//  AnalyticsManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 29.06.2021.
//

import Foundation
import VidyoClientIOS

class AnalyticsManager {
    let connector = ConnectorManager.shared.connector

    func controlGoogleAnalyticsEventAction(_ category: VCConnectorGoogleAnalyticsEventCategory, _ action: VCConnectorGoogleAnalyticsEventAction, _ enable: Bool) -> Bool {
        connector.googleAnalyticsControlEventAction(category, eventAction: action, enable: enable)
    }

    func startGoogleAnalyticsService(withOptions options: VCConnectorGoogleAnalyticsOptions?) -> Bool {
        return connector.startGoogleAnalyticsService(options)
    }

    func startInsightsService(withEnteredData data: String) -> Bool {
        return connector.startInsightsService(data)
    }

    func stopGoogleAnalyticsService() -> Bool {
        return connector.stopGoogleAnalyticsService()
    }

    func stopInsightsService() -> Bool {
        return connector.stopInsightsService()
	}

    func isGoogleAnalyticsServiceEnabled() -> Bool {
        return connector.isGoogleAnalyticsServiceEnabled()
    }

    func isInsightsServiceEnabled() -> Bool {
        return connector.isInsightsServiceEnabled()
    }

    func getGoogleAnalyticOptions(_ object: VCConnectorIGetGoogleAnalyticsOptions) {
        connector.getGoogleAnalyticsOptions(object)
    }

    func getInsightsServiceUrl() -> String {
        return connector.getInsightsServiceUrl()
    }

    static func getDefaultGoogleAnalyticOptions() -> VCConnectorGoogleAnalyticsOptions? {
        var options:VCConnectorGoogleAnalyticsOptions?

        if let plist = Bundle.main.path(forResource: "Info", ofType: "plist") {
            let id = NSDictionary(contentsOfFile: plist)?.value(forKey: "GoogleAnalyticId") as? NSMutableString
            let key = NSDictionary(contentsOfFile: plist)?.value(forKey: "GoogleAnalyticKey") as? NSMutableString

            if (id != nil && key != nil) {
                options = VCConnectorGoogleAnalyticsOptions()

                options?.id = id
                options?.key = key
            }
        }
        return options
    }
    
    static func getDefaultInsightServerUrl() -> String {

        if let plist = Bundle.main.path(forResource: "Info", ofType: "plist") {
            let url = NSDictionary(contentsOfFile: plist)?.value(forKey: "insightServerUrl") as? NSMutableString

            if (url != nil) {
                return url! as String;
            }
        }
        return "";
    }
}
