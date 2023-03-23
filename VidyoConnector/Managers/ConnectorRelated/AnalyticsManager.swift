//
//  AnalyticsManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 29.06.2021.
//

import Foundation

class AnalyticsManager {
    let connector = ConnectorManager.shared.connector

    func controlGoogleAnalyticsEventAction(_ category: VCConnectorGoogleAnalyticsEventCategory, _ action: VCConnectorGoogleAnalyticsEventAction, _ enable: Bool) -> Bool {
        connector.googleAnalyticsControlEventAction(category, eventAction: action, enable: enable)
    }

    func startGoogleAnalyticsService(withEnteredData data: String) -> Bool {
        return connector.startGoogleAnalyticsService(data)
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

    func getGoogleAnalyticsServiceId() -> String {
        return connector.getGoogleAnalyticsServiceID()
    }

    func getInsightsServiceUrl() -> String {
        return connector.getInsightsServiceUrl()
    }

    static func getDefaultGoogleAnalyticId() -> String {
        var googleAnalyticId = ""
        if let infoPlistPath = Bundle.main.path(forResource: "Info", ofType: "plist") {
            googleAnalyticId = NSDictionary(contentsOfFile: infoPlistPath)?.value(forKey: "GoogleAnalyticId") as? String ?? ""
        }
        return googleAnalyticId
    }
}
