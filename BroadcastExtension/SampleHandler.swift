//
//  SampleHandler.swift
//  BroadcastExtension
//
//  Created by Marta Korol on 19.07.2021.
//

import ReplayKit
import CFNotificationCenterWrapper

class SampleHandler: RPBroadcastSampleHandler {
    
    let imageConverter = ShareImageConverter()
    let notificationCenter = CFNotificationCenterWrapper()
    let defaults = UserDefaults(suiteName: BroadcastExtensionConstants.applicationGroupIdentifier)!
    let socket: ServerSocket = ServerSocket(applicationGroupIdentifier: BroadcastExtensionConstants.applicationGroupIdentifier)
    
    var startTime: Date?
    
    let lock = NSLock()
    var scheduledBuffer: CMSampleBuffer?
    lazy var sendThread: Thread = {
        let thread = Thread(target: self, selector: #selector(sendThreadHandler), object: nil)
        thread.name = "ScreenShareExtensionSendThread"
        thread.qualityOfService = .userInitiated
        return thread
    }()
    
    // MARK: - Lifecycle
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        super.broadcastStarted(withSetupInfo: setupInfo)
        
        startTime = Date()
        
        notificationCenter.add(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.callEnded)
        notificationCenter.add(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.unknownError)
        
        guard socket.startServer(clientConnectCallback: { [unowned self] timeout in
            if timeout {
                self.finishBroadcastWithErrorReason(BroadcastExtensionConstants.Screenshare.noActiveConferenceError,
                                                    skipDelay: true)
            } else if self.socket.isSocketsAlive {
                self.sendThread.start()
            }
        }) else {
            DispatchQueue.global().async { self.finishBroadcastWithErrorReason("Error") }
            return
        }
        
        notificationCenter.postNotification(withName: BroadcastExtensionConstants.CFNotificationNames.broadcastStarted)
        defaults.set(true, forKey: BroadcastExtensionConstants.isBroadcastStarted)
        defaults.synchronize()
    }
    
    override func broadcastPaused() {
        super.broadcastPaused()
        notificationCenter.postNotification(withName: BroadcastExtensionConstants.CFNotificationNames.broadcastPaused)
    }
    
    override func broadcastResumed() {
        super.broadcastResumed()
        notificationCenter.postNotification(withName: BroadcastExtensionConstants.CFNotificationNames.broadcastResumed)
    }
    
    override func broadcastFinished() {
        super.broadcastFinished()
        defaults.set(false, forKey: BroadcastExtensionConstants.isBroadcastStarted)
        defaults.synchronize()
        notificationCenter.postNotification(withName: BroadcastExtensionConstants.CFNotificationNames.broadcastFinished)
        cleanupExtension()
    }
    
    override func finishBroadcastWithError(_ error: Error) {
        super.finishBroadcastWithError(error)
        cleanupExtension()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            lock.lock()
            scheduledBuffer = sampleBuffer
            lock.unlock()
        default: break
        }
    }
    
    // MARK: - Methods
    @objc private func sendThreadHandler() {
        while !Thread.current.isCancelled {
            autoreleasepool { [unowned self] in
                lock.lock()
                guard let sbuff = scheduledBuffer else {
                    lock.unlock()
                    Thread.sleep(forTimeInterval: 0.05)
                    return
                }
                scheduledBuffer = nil
                lock.unlock()
                self.writeSample(buff: sbuff)
            }
        }
    }
    
    private func cleanupExtension() {
        sendThread.cancel()
        
        notificationCenter.postNotification(withName: BroadcastExtensionConstants.CFNotificationNames.broadcastFinished)
        
        socket.terminateConnection()
        
        notificationCenter.remove(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.callEnded)
        notificationCenter.remove(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.unknownError)
    }
    
    private func writeSample(buff: CMSampleBuffer) {
        if !CMSampleBufferDataIsReady(buff) { CMSampleBufferMakeDataReady(buff) }
        if let orientationDeviation = buff.replayKitFrameOrientationDeviation() {
            let orientNum = NSNumber(value: orientationDeviation.rawValue)
            defaults.set(orientNum, forKey: BroadcastExtensionConstants.orientationDefaultsKey)
        }
        
        guard
            let imageBuffer = CMSampleBufferGetImageBuffer(buff),
            let packet = imageConverter.packetDataFromBuffer(imageBuffer: imageBuffer)
        else { return }
        
        defaults.set(packet.0.count, forKey: BroadcastExtensionConstants.frameDataLengthKey)
        defaults.set(packet.1, forKey: BroadcastExtensionConstants.ioSurfacePropertiesDefaultsKey)
        defaults.synchronize()
        
        socket.send(packet.0, firstPacketSentCallback: { [weak self] in
            self?.notificationCenter.postNotification(withName: BroadcastExtensionConstants.CFNotificationNames.newFrameAvailable)
        })
    }
    
    private func finishBroadcastWithErrorReason(_ reason: String, skipDelay: Bool = false) {
        let minDelay = BroadcastExtensionConstants.extensionFinishDelay
        let finishBlock = { self.finishBroadcastWithError(
            NSError(domain: BroadcastExtensionConstants.bundleId,
                    code: 122,
                    userInfo: [NSLocalizedFailureReasonErrorKey : reason])
        ) }
        
        if skipDelay || minDelay == 0 {
            finishBlock()
        } else if let startDate = startTime {
            let delay = max(0, minDelay - Date().timeIntervalSince(startDate))
            guard delay > 0 else {
                finishBlock()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { finishBlock() }
        } else {
            DispatchQueue.global().asyncAfter(deadline: .now() + minDelay) { finishBlock() }
        }
    }
}

// MARK: - CFNotificationCenterWrapperObserver
extension SampleHandler: CFNotificationCenterWrapperObserver {
    func onDarwinNotification(withName name: String) {
        switch name {
        case BroadcastExtensionConstants.CFNotificationNames.callEnded:
            finishBroadcastWithErrorReason(BroadcastExtensionConstants.Screenshare.noActiveConferenceError)
        case BroadcastExtensionConstants.CFNotificationNames.unknownError:
            finishBroadcastWithErrorReason(BroadcastExtensionConstants.Screenshare.systemError)
        default: break
        }
    }
}
