//
//  SceneDelegate.swift
//  VidyoConnector
//
//  Created by Marta Korol on 18.05.2021.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        log.info("SceneWillResignActive")
        ConnectorManager.shared.handleBackground()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        log.info("SceneDidBecomeActive")
        ConnectorManager.shared.handleForeground()
    }
}

