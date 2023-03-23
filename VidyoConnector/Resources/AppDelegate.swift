//
//  AppDelegate.swift
//  VidyoConnector
//
//  Created by Marta Korol on 18.05.2021.
//

import UIKit
import os

let log = Logger()

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        VCConnectorPkg.vcInitialize()
        
        let analyticId = AnalyticsManager.getDefaultGoogleAnalyticId()
        if(!analyticId.isEmpty) {
            if !VCConnectorPkg.setExperimentalOptions("{\"googleAnalyticsDefaultId\":\"" + analyticId + "\"}") {
                log.error("Failed to set experimental options")
            }
        }
        return true
    }

    // MARK: - UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        if ConnectorManager.shared.connectionManager.connectionState == .connected {
            ConnectorManager.shared.disable()
        }
        VCConnectorPkg.uninitialize()
    }
}

