//
//  InstantiateVCFactory.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 10.06.2021.
//

import Foundation

protocol StoryboardInstantiatable {
    func instantiateFromStoryboard() -> UIViewController
}

class InstantiateFromStoryboardFactory: StoryboardInstantiatable {
    
    enum StoryboardID: String {
        case main = "Main"
    }
    
    enum NavigationControllerID: String {
        case settingsNC = "SettingsNavigationController"
        case chatNC = "ChatNavigationController"
        case backgroundNC = "BackgroundNavigationController"
    }
    
    var storyboardID: StoryboardID
    
    init(storyboardID: StoryboardID = .main) {
        self.storyboardID = storyboardID
    }
    
    func instantiateFromStoryboard<T: UIViewController>() -> T {
        let storyboard = UIStoryboard(name: storyboardID.rawValue, bundle: nil)
        guard let controller = storyboard.instantiateViewController(withIdentifier: String(describing: T.self)) as? T else {
            fatalError("Failed to instantiate ViewController with identifier \(String(describing: T.self)) from storyboard.")
        }
        return controller
    }
    
    func instantiateNavigationController<T: UINavigationController>(with identifier: NavigationControllerID) -> T {
        let storyboard = UIStoryboard(name: storyboardID.rawValue, bundle: nil)
        guard let controller = storyboard.instantiateViewController(withIdentifier: identifier.rawValue) as? T else {
            fatalError("Failed to instantiate NavigationController with identifier \(identifier.rawValue))from storyboard.")
        }
        return controller
    }
}
