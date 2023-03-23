//
//  AppFrameListener.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 25.07.2021.
//

import UIKit

class AppFrameListener: NSObject {
    static let frameKeyPath = "frame"
    
    let window: UIWindow
    let pullingInterval: TimeInterval = 1
    var isPulling = false {
        didSet { updateActivePullingState() }
    }
    private(set) var currentScreenSpace: ScreenSpace = .fullScreen {
        didSet {
            log.info("Current app screen space - \(String(describing: self.currentScreenSpace))")
        }
    }
    private(set) var appFrame: CGRect
 
    private var inBackground = false {
        didSet { updateActivePullingState() }
    }
    private var framePullTimer: Timer? {
        willSet { framePullTimer?.invalidate() }
    }
    
    // MARK: - Initialisation
    init(window: UIWindow) {
        self.window = window
        self.appFrame = window.absoluteFrame()
        super.init()
        
        updateScreenSpace()
        addObservers()
    }
    
    deinit {
        removeObservers()
        framePullTimer?.invalidate()
        framePullTimer = nil
    }
    
    // MARK: - Methods
    private func addObservers() {
        self.window.addObserver(self,
                                forKeyPath: AppFrameListener.frameKeyPath,
                                options: NSKeyValueObservingOptions.new,
                                context: nil)
        
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.inBackground = false
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.inBackground = true
        }
    }
    
    private func removeObservers() {
        window.removeObserver(self, forKeyPath: AppFrameListener.frameKeyPath)
        NotificationCenter.default.removeObserver(self)
    }
    
    private func updateActivePullingState() {
        if isPulling && !inBackground {
            guard !(framePullTimer?.isValid ?? false) else { return }
            framePullTimer = Timer.scheduledTimer(withTimeInterval: pullingInterval, repeats: true) { [weak self] _ in
                self?.updateWindowFrame()
            }
        } else {
            framePullTimer = nil
        }
    }
    
    private func updateWindowFrame() {
        let newFrame = window.absoluteFrame()
        guard newFrame != appFrame else {
            return
        }
        appFrame = newFrame
        updateScreenSpace()
    }
    
    private func updateScreenSpace() {
        if appFrame.origin.y > 0 {
            currentScreenSpace = .slideOver
        } else if appFrame != window.screen.bounds {
            currentScreenSpace = .splitView(appFrame)
        } else {
            currentScreenSpace = .fullScreen
        }
    }
}
