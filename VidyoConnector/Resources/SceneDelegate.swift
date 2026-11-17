//
//  SceneDelegate.swift
//  VidyoConnector
//
//  Created by Marta Korol on 18.05.2021.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var pendingBackgroundWorkItem: DispatchWorkItem?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        log.info("SceneWillResignActive")
        // System PiP: ConferenceViewController starts PiP on willDeactivate and sets
        // ConnectorManager.isSystemPiPActive. Delay handleBackground() briefly so that flag
        // is set first — otherwise the connector enters background mode and PiP frames stop.
        pendingBackgroundWorkItem?.cancel()
        let work = DispatchWorkItem {
            ConnectorManager.shared.handleBackground()
        }
        pendingBackgroundWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        log.info("SceneDidBecomeActive")
        // Cancel any pending delayed background so a quick foreground flip never mutes devices.
        pendingBackgroundWorkItem?.cancel()
        pendingBackgroundWorkItem = nil
        ConnectorManager.shared.handleForeground()
    }
}
