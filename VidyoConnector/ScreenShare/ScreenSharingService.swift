//
//  ScreenSharingService.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 25.07.2021.
//

import UIKit
import AVFoundation
import ReplayKit
import CFNotificationCenterWrapper

class ScreenSharingService {
    private struct StreamConfig {
        static let maxResolution = 720
        static var maxFPS: Int {
            shareServices.isHighFrameRateShare ? 30 : 3
        }
    }
    
    private struct ShareContext {
        let shareOuptut: ScreenShareOutputProtocol
        var started: Bool { return shareOuptut.started }
        var previousFrameSize: CGSize
        var sendSleepSeconds: TimeInterval
    }
    
    private enum Exception: Error {
        case FailedToConnectSocket
        case FailedToCreateVirtualShare
    }

    // MARK: - Const & vars
    var isShareInProgress: Bool { return shareCtx != nil }
    private var isReconnectInProgress: Bool = false
    private var firstFrameTimeoutTimer: Timer?
    
    private let notificationCenter = CFNotificationCenterWrapper()
    private let persistance = UserDefaults(suiteName: BroadcastExtensionConstants.applicationGroupIdentifier)!

    // Stream
    private var socket = ClientSocket(applicationGroupIdentifier: BroadcastExtensionConstants.applicationGroupIdentifier)
    private var readingQueue = OperationQueue()
    private var sendThread: Thread?

    private var currentFrameData: FrameData?

    private let extensionStreamFPSCounter = EventIntervalCounter(reportCallback: { interval in
        let fps = 1.0 / interval
        log.info("Broadcast Extension FPS: \(String(fps))")
    })
    private let sendStreamFPSCounter = EventIntervalCounter(reportCallback: { interval in
        let fps = 1.0 / interval
        log.info("App screen share FPS: \(String(fps))")
    }, wrapCount: 30)

    // Vidyo Share
    private var shareCtx: ShareContext?
    private let shareOutputFactory: ScreenShareOutputFactory

    // Frame transformations
    private let cropHandler: ScreenSharingCropHandler
    private let ciContext = CIContext()
    private let imageConverter = ShareImageConverter()
    private var appFrameListener: AppFrameListener { return ShareAppServices.shared.appFrameListener }

    // MARK: - Initialisation
    init(appFrameListener: AppFrameListener = ShareAppServices.shared.appFrameListener,
         shareOutputFactory: ScreenShareOutputFactory) {
        self.shareOutputFactory = shareOutputFactory
        cropHandler = ScreenSharingCropHandler(appFrameListener: appFrameListener)
        readingQueue.maxConcurrentOperationCount = 1
        readingQueue.qualityOfService = .userInteractive
    }
    
    // MARK: - Main methods
    func activate() {
        log.info("ScreenSharingService activated")
        subscribeToCFNotifications()
    }
    
    func deactivate() {
        log.info("ScreenSharingService deactivated")
        unsubscribeToCFNotifications()
        stopSharing(sendNotification: BroadcastExtensionConstants.CFNotificationNames.callEnded)
    }
    
    private func startSharing() {
        log.info("Starting Screen Share")
        guard !isReconnectInProgress else {
            log.info("Broadcast extension start declined - reconnection is in progress")
            return
        }
        do {
            try prepareVirtualShare()
            try startSocket()
            
            extensionStreamFPSCounter.start()
            sendStreamFPSCounter.start()
            enableFirstFrameTimeout()
            
            log.info("Share started")
        } catch {
            log.error("Broadcast extension start declined")
            notificationCenter.postNotification(withName: BroadcastExtensionConstants.CFNotificationNames.unknownError)
        }
    }
    
    private func stopSharing(sendNotification notificationName: String? = nil) {
        log.info("Stopping screen share - notificationName: \(String(describing: notificationName))")
        currentFrameData = nil
        guard isShareInProgress else {
            log.info("No started share. Ignoring the request")
            return
        }
        
        disableFirstFrameTimeout()
        stopSocket()
        extensionStreamFPSCounter.stop()
        sendStreamFPSCounter.stop()
        
        if let shareContext = shareCtx {
            do {
                try shareContext.shareOuptut.stop()
            } catch {
                log.error("Error during stop screen share stream \(String(describing: error))")
            }
            shareCtx = nil
        }
        
        if let notification = notificationName {
            notificationCenter.postNotification(withName: notification)
        }
        log.info("Share stopped")
    }
}

// MARK: - ScreenSharingService & VirtualShare
extension ScreenSharingService {
    func prepareVirtualShare() throws {
        do {
            let constraints = ScreenShareOutputMaxConstraints(maxFPS: StreamConfig.maxFPS)
            var stream = try shareOutputFactory.createShareOuptut(constraints: constraints)
            stream.listener = self
            shareCtx = ShareContext(shareOuptut: stream,
                                    previousFrameSize: CGSize.zero,
                                    sendSleepSeconds: UnitsConversion.secondTimeInterval(fps: 5))
            try stream.start()
        } catch {
            log.error("Failed to create and start virtual share \(String(describing: error))")
            assertionFailure()
            throw Exception.FailedToCreateVirtualShare
        }
    }
}

// MARK: - ScreenSharingService & Sockets
private extension ScreenSharingService {
    func startSocket() throws {
        log.info("Starting ScreenSharingService socket")
        if socket.isSocketAlive {
            log.error("Previous socket is alive. May lead to unexpected troubles")
            assertionFailure("Previous socket is alive. May lead to unexpected troubles")
            socket.terminateConnection()
        }
        
        socket.connectToServer()
        guard socket.isSocketAlive else {
            log.error("Socket fialed to connect")
            throw Exception.FailedToConnectSocket
        }
        
        readingQueue.isSuspended = false
        sendThread?.cancel()
        sendThread = {
            let thread = Thread(target: self, selector: #selector(sendThreadHandler), object: nil)
            thread.name = "VidyoScreenShareSendThread"
            thread.qualityOfService = .userInteractive
            return thread
        }()
        sendThread?.start()
    }
    
    func stopSocket() {
        log.info("Stoping ScreenSharingService socket")
        guard socket.isSocketAlive else {
            log.info("No sockets alive. Ignoring")
            return
        }
        readingQueue.isSuspended = true
        readingQueue.cancelAllOperations()
        sendThread?.cancel()
        socket.terminateConnection()
    }
    
    @objc private func sendThreadHandler() {
        let noDataDelay = 0.1 // 100 milliseconds
        while !Thread.current.isCancelled  {
            autoreleasepool { [unowned self] in
                guard let virtualShare = self.shareCtx, virtualShare.started else {
                    log.warning("No virtual share inside \(#function) loop")
                    Thread.sleep(forTimeInterval: noDataDelay)
                    return
                }
                guard let frameData = self.currentFrameData else {
                    log.warning("No frame data inside \(#function) loop")
                    Thread.sleep(forTimeInterval: noDataDelay)
                    return
                }
                let start = CACurrentMediaTime()
                sendStreamFPSCounter.tick()
                preparePixelBuffer(from: frameData) { shareCtx?.shareOuptut.sendBuffer($0) }

                let sleepTime = virtualShare.sendSleepSeconds - (CACurrentMediaTime() - start)
                if sleepTime > 0 {
                    Thread.sleep(forTimeInterval: sleepTime)
                }
            }
        }
    }
}

// MARK: - ScreenSharingService & Stream
extension ScreenSharingService {
    private func fetchNewFrame() {
        extensionStreamFPSCounter.tick()
        disableFirstFrameTimeout()
        
        guard let dataLength = persistance.object(forKey: BroadcastExtensionConstants.frameDataLengthKey) as? Int else {
            log.error("fetch new frame - no data length")
            return
        }
        
        let surfaceProps = persistance.object(forKey: BroadcastExtensionConstants.ioSurfacePropertiesDefaultsKey) as! CFDictionary
        
        let orientation = CGImagePropertyOrientation(rawValue: (persistance.object(forKey: BroadcastExtensionConstants.orientationDefaultsKey) as! NSNumber).uint32Value)!
        
        readingQueue.addOperation { [weak self] in
            guard let `self` = self else { return }
            guard let pixelBuffer = self.getPixelBuffer(dataLength: dataLength, surfaceProperties: surfaceProps) else {
                log.warning("No pixel buffer on read")
                return
            }
            
            self.currentFrameData = FrameData(imageOrientation: orientation, unmanagedPixelBuffer: pixelBuffer)
        }
    }
    
    private func getPixelBuffer(dataLength: Int, surfaceProperties: CFDictionary) -> Unmanaged<CVImageBuffer>? {
        guard var data = socket.read(Int32(dataLength)) else {
            assertionFailure()
            return nil
        }
        guard let marker = data.range(of: BroadcastExtensionConstants.frameDataStartMarker) else { return nil }
        if marker.startIndex > 0 {
            guard let moreData = socket.read(Int32(marker.startIndex)) else {
                assertionFailure()
                return nil
            }
            var subdata = data.subdata(in: Range(marker.endIndex...dataLength))
            subdata.append(moreData)
            data = subdata
        }
        guard let start = data.range(of: BroadcastExtensionConstants.frameDataStartMarker),
            let end = data.range(of: BroadcastExtensionConstants.frameDataEndMarker),
            let surface = IOSurfaceCreate(surfaceProperties) else {
                return nil
        }
        var pixelBuffer: Unmanaged<CVImageBuffer>?
        CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, surface, nil, &pixelBuffer)
        let pixelBufferValue = pixelBuffer!.takeUnretainedValue()
        CVPixelBufferLockBaseAddress(pixelBufferValue, [])
        
        let surf = CVPixelBufferGetIOSurface(pixelBufferValue)
        let dest = IOSurfaceGetBaseAddress(surf!.takeUnretainedValue())
        let range: Range<Int> = Range(start.endIndex...end.startIndex)
        let frameData = data.subdata(in: range) as NSData
        memcpy(dest, frameData.bytes, frameData.length)
        CVPixelBufferUnlockBaseAddress(pixelBufferValue, [])
        return pixelBuffer
    }
 
    private func preparePixelBuffer(from frameData: FrameData, receiver: (CVPixelBuffer) -> Void) {
        let pixelBuffer = frameData.pixelBuffer.takeUnretainedValue()
        guard let ciImage = self.imageConverter.ciImageFrom(pixelBuffer: pixelBuffer, orientationDeviation: frameData.imageOrientation) else {
            assertionFailure("Failed to create and rotate CIImage from pixel buffer")
            log.error("Failed to create and rotate CIImage from pixel buffer")
            return
        }
        let finalCIImage = self.processFrame(ciImage, sourceBuffer: pixelBuffer)
        
        if finalCIImage.extent.size != shareCtx?.previousFrameSize ?? CGSize.zero {
            self.updateVirtualShareBounds(finalCIImage.extent.size)
        }
        
        guard let finalBuffer = finalCIImage.pixelBuffer else {
            assertionFailure("Failed to get pixel buffer for sending")
            log.error("Failed to get pixel buffer for sending")
            return
        }
        receiver(finalBuffer)
        shareCtx?.previousFrameSize = finalCIImage.extent.size
    }
    
    private func processFrame(_ ciImage: CIImage, sourceBuffer: CVPixelBuffer) -> CIImage {
        let croppedImage = self.cropHandler.crop(ciImage: ciImage)        
        let scale = min(1, CGFloat(StreamConfig.maxResolution) / min(croppedImage.extent.width, croppedImage.extent.height))
        let transform = CGAffineTransform(translationX: -croppedImage.extent.minX, y: 0)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        var finalImage = croppedImage.transformed(by: transform)
        var imageExtent = finalImage.extent
        if imageExtent.width.truncatingRemainder(dividingBy: 2.0) != 0 {
            imageExtent.size.width -= 1
            if imageExtent.origin.x > 0 {
                imageExtent.origin.x += 1
            }
            finalImage = finalImage.cropped(to: imageExtent)
        }
        var newBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                            Int(imageExtent.width),
                            Int(imageExtent.height),
                            CVPixelBufferGetPixelFormatType(sourceBuffer),
                            nil,
                            &newBuffer)
        ciContext.render(finalImage, to: newBuffer!)
        return CIImage(cvPixelBuffer: newBuffer!)
    }
    
    private func updateVirtualShareBounds(_ size: CGSize) {
        let maxSize = size.capped(at: CGFloat(StreamConfig.maxResolution))
        
        guard let stream = shareCtx?.shareOuptut else {
            log.error("Missing share stream")
            return
        }
        stream.set(maxConstraints: .init(maxFPS: StreamConfig.maxFPS, maxSize: maxSize))
    }
}

//MARK: - ScreenSharingService & FirstFrameTimeout
extension ScreenSharingService {
    static private let FirstFrameTimeout: TimeInterval = 3.0
    
    private func enableFirstFrameTimeout() {
        firstFrameTimeoutTimer = Timer.scheduledTimer(withTimeInterval: ScreenSharingService.FirstFrameTimeout,
                                                      repeats: false,
                                                      block:
        { [weak self] _ in
            log.error("First frame did not arrive for started screen sharing")
            self?.stopSharing(sendNotification: BroadcastExtensionConstants.CFNotificationNames.unknownError)
        })

    }
    
    private func disableFirstFrameTimeout() {
        firstFrameTimeoutTimer?.invalidate()
        firstFrameTimeoutTimer = nil
    }
}

//MARK: - ScreenShareOutputListener
extension ScreenSharingService: ScreenShareOutputListener {
    func onStart(_ stream: ScreenShareOutputProtocol, recommendedFPS: Int) {
        log.info("Share stream start, recommended fps \(recommendedFPS)")
        shareCtx?.sendSleepSeconds = UnitsConversion.secondTimeInterval(fps: recommendedFPS)
    }
    
    func onStop(_ stream: ScreenShareOutputProtocol) {
        log.info("Share stream stop")
    }
    
    func onReconfigure(_ stream: ScreenShareOutputProtocol, recommendedFPS: Int) {
        log.info("Share stream reconfigure, recommended fps \(recommendedFPS)")
        shareCtx?.sendSleepSeconds = UnitsConversion.secondTimeInterval(fps: recommendedFPS)
    }
}

// MARK: - Darwin Notifications
extension ScreenSharingService: CFNotificationCenterWrapperObserver {
    private func subscribeToCFNotifications() {
        notificationCenter.add(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.broadcastStarted)
        notificationCenter.add(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.broadcastPaused)
        notificationCenter.add(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.broadcastResumed)
        notificationCenter.add(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.broadcastFinished)
        notificationCenter.add(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.newFrameAvailable)
    }
    
    private func unsubscribeToCFNotifications() {
        notificationCenter.remove(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.broadcastStarted)
        notificationCenter.remove(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.broadcastPaused)
        notificationCenter.remove(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.broadcastResumed)
        notificationCenter.remove(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.broadcastFinished)
        notificationCenter.remove(self, forNotificationName: BroadcastExtensionConstants.CFNotificationNames.newFrameAvailable)
    }
    
    func onDarwinNotification(withName name: String) {
        if name != BroadcastExtensionConstants.CFNotificationNames.newFrameAvailable {
            log.info("Broadcast extension notification with name: \(name)")
        }
        
        switch name {
        case BroadcastExtensionConstants.CFNotificationNames.broadcastStarted:
            startSharing()
            NotificationCenter.default.post(name: .shareBroadcastStarted, object: nil)
            NotificationCenter.default.post(name: .conferenceBroadcastStarted, object: nil)
            log.info("Broadcast started")
        case BroadcastExtensionConstants.CFNotificationNames.broadcastPaused:
            log.info("Broadcast paused")
        case BroadcastExtensionConstants.CFNotificationNames.broadcastResumed:
            log.info("Broadcast resumed")
        case BroadcastExtensionConstants.CFNotificationNames.broadcastFinished:
            NotificationCenter.default.post(name: .shareBroadcastFinished, object: nil)
            NotificationCenter.default.post(name: .conferenceBroadcastFinished, object: nil)
            stopSharing()
            log.info("Broadcast finished")
        case BroadcastExtensionConstants.CFNotificationNames.newFrameAvailable:
            fetchNewFrame()
        default: break
        }
    }
}
