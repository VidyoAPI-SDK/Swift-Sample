//
//  ShareAppServices.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 25.07.2021.
//

import Foundation

let shareServices = ShareAppServices.shared

class ShareAppServices {
    static let shared = ShareAppServices()
    
    private let accessQueue = DispatchQueue.global(qos: .userInteractive)
    
    var isHighFrameRateShare: Bool = false
    var screenSharingService: ScreenSharingService?
    var appFrameListener: AppFrameListener {
        return getAppFrameListener()!
    }
    
    private init () {}
    
    // MARK: - Methods
    @objc func onConferenceAvailable() {
        if screenSharingService == nil {
            screenSharingService = getScreenSharingService()
        }
        appFrameListener.isPulling = true
        screenSharingService?.activate()
    }
    
    @objc func onConferenceUnavailable() {
        appFrameListener.isPulling = false
        screenSharingService?.deactivate()
        removeConferenceObservers()
    }
    
    func addConferenceObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onConferenceAvailable),
                                               name: .conferenceAvailable,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onConferenceUnavailable),
                                               name: .noConferenceAvailable,
                                               object: nil)
    }
    
    func removeConferenceObservers() {
        NotificationCenter.default.removeObserver(self)
    }
 
    private func getAppFrameListener() -> AppFrameListener? {
        var service: AppFrameListener?
        let window: UIWindow = {
            guard let delegate = UIApplication.shared.delegate else { return UIWindow() }
            guard let window = delegate.window ?? UIWindow() else { return UIWindow() }
            return window
        }()
        let appFrame = AppFrameListener(window: window)
        accessQueue.sync {
            service = appFrame
        }
        return service
    }
    
    private func getScreenSharingService() -> ScreenSharingService? {
        var service: ScreenSharingService?
        let shareOutputFactory = ScreenShareOutputFactory()
        accessQueue.sync {
            service = ScreenSharingService(shareOutputFactory: shareOutputFactory)
        }
        return service
    }
}
