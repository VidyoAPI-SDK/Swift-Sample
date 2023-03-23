//
//  ScreenSharingCropHandler.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 25.07.2021.
//

import Foundation

class ScreenSharingCropHandler {
    typealias CIImageCropStrategy = (CIImage) -> (CIImage)
    private static let noCropStrategy: CIImageCropStrategy = { return $0 }

    private let appFrameListener: AppFrameListener
    private var cropStrategy: CIImageCropStrategy = ScreenSharingCropHandler.noCropStrategy
    
    // MARK: - Initialisation
    init(appFrameListener: AppFrameListener) {
        self.appFrameListener = appFrameListener
        handleAppScreenSpaceChange(newSpace: appFrameListener.currentScreenSpace)
        startObservingAppState()
    }
    
    deinit {
        stopObservingAppState()
    }
    
    // MARK: - Methods
    func crop(ciImage: CIImage) -> CIImage {
        return cropStrategy(ciImage)
    }
    
    private func handleAppScreenSpaceChange(newSpace: ScreenSpace) {
        guard Thread.isMainThread else {
            let msg = "\(#function) should only be called on the main thread"
            assertionFailure(msg)
            return
        }
        guard UIApplication.shared.applicationState != .background else {
            cropStrategy = ScreenSharingCropHandler.noCropStrategy
            return
        }
        
        switch newSpace {
        case ScreenSpace.splitView(let appFrame):
            cropStrategy = ScreenSharingCropHandler.cropStrategy(appFrame: appFrame,
                                                                 screen: appFrameListener.window.screen)
        default:
            cropStrategy = ScreenSharingCropHandler.noCropStrategy
        }
    }
    
    private static func cropStrategy(appFrame: CGRect, screen: UIScreen) -> CIImageCropStrategy {
        let area = (try? visibleArea(appFrame: appFrame, screenBounds: screen.bounds)) ?? RelativeRect.completeRect
        
        return { ciImage in
            let cropRect = area.cropRect(ciImage.extent)
            let croppedImage = ciImage.cropped(to: cropRect)
            return croppedImage
        }
    }
    
    static private func visibleArea(appFrame: CGRect, screenBounds: CGRect) throws -> RelativeRect {
        guard appFrame != screenBounds else { return RelativeRect.completeRect }
        let width: CGFloat = 1.0 - (appFrame.size.width / screenBounds.size.width)
        let x = { () -> CGFloat in
            if appFrame.origin.x == screenBounds.origin.x {
                return 1.0 - width
            } else {
                return 0.0
            }
        }()
        return try RelativeRect(x: x, y: 0, width: width, height: 1)
    }
}

//MARK: - ScreenSharingCropHandler & Observers
extension ScreenSharingCropHandler {
    private func startObservingAppState() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onWillResignActive(_:)),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDidEnterBackground(_:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onWillEnterForeground(_:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onDidBecomeActive(_:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    private func stopObservingAppState() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func onWillResignActive(_ notification: Notification) {
        handleAppScreenSpaceChange(newSpace: appFrameListener.currentScreenSpace)
    }
    
    @objc private func onDidEnterBackground(_ notification: Notification) {
        handleAppScreenSpaceChange(newSpace: appFrameListener.currentScreenSpace)
    }
    
    @objc private func onWillEnterForeground(_ notification: Notification) {
        handleAppScreenSpaceChange(newSpace: appFrameListener.currentScreenSpace)
    }
    
    @objc private func onDidBecomeActive(_ notification: Notification) {
        handleAppScreenSpaceChange(newSpace: appFrameListener.currentScreenSpace)
    }
}
