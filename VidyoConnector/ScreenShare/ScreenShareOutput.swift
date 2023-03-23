//
//  ScreenShareOutput.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 25.07.2021.
//

import UIKit

class ScreenShareOutput: ScreenShareOutputProtocol {
    
    weak var listener: ScreenShareOutputListener?
    private var source: VCVirtualVideoSource
    private var sourceManager = VirtualVideoSourceManager()
    private(set) var started = false
    
    // MARK: - Initialisation
    init?(constraints: ScreenShareOutputMaxConstraints) {
        guard let virtualVideoSource = sourceManager.getVirtualVideoSource() else {
            log.error("Failed to create virtual video source")
            return nil
        }
        self.source = virtualVideoSource
        source.set(maxConstraints: constraints)
        
        setupVirtualVideoSourceStateHandlers()
    }
    
    // MARK: - Methods
    func start() throws {
        log.info("Start Screen Share")
        guard !started else {
            throw ScreenShareOutputException.startingActiveStream
        }
        started = true
        sourceManager.selectVirtualSourceWindowShare(source)
    }
    
    func stop() throws {
        log.info("Stop Screen Share")
        guard started else {
            throw ScreenShareOutputException.stoppingInactiveStream
        }
        started = false
        sourceManager.selectVirtualSourceWindowShare(nil)
    }
    
    func set(maxConstraints: ScreenShareOutputMaxConstraints) {
        source.setMaxConstraints(UInt32(maxConstraints.maxSize.width),
                          height: UInt32(maxConstraints.maxSize.height),
                          frameInterval: Int(UnitsConversion.frameInterval(fps: maxConstraints.maxFPS)))
    }
    
    func setupVirtualVideoSourceStateHandlers() {
        sourceManager.onStartHandler = { [weak self] (frameInterval, mediaFormat) in
            guard let self = self else { return }
            log.info("ScreenShare started with frame interval - \(String(describing: frameInterval)), mediaFormat - \(String(mediaFormat.rawValue))")
            self.listener?.onStart(self, recommendedFPS: UnitsConversion.fps(frameInterval: frameInterval))
        }
        
        sourceManager.onStopHandler = { [weak self] in
            guard let self = self else { return }
            log.info("ScreenShare stoped")
            self.listener?.onStop(self)
        }
        
        sourceManager.onReconfigureHandler = { [weak self] (frameInterval, mediaFormat) in
            guard let self = self else { return }
            log.info("ScreenShare configuration changed with frame interval - \(frameInterval), mediaFormat - \(String(mediaFormat.rawValue))")
            self.listener?.onReconfigure(self, recommendedFPS: UnitsConversion.fps(frameInterval: frameInterval))
        }
    }
    
    func sendBuffer(_ buffer: CVImageBuffer) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        let finalSize = (CVPixelBufferGetHeightOfPlane(buffer, 1) * CVPixelBufferGetWidthOfPlane(buffer, 1) * 2) + (CVPixelBufferGetHeightOfPlane(buffer, 0) * CVPixelBufferGetWidthOfPlane(buffer, 0))
        let finalBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: finalSize)
        var bufferPointee = finalBuffer
        let planeCount = CVPixelBufferGetPlaneCount(buffer)
        for i in 0..<planeCount {
            let planeBuffer = CVPixelBufferGetBaseAddressOfPlane(buffer, i)!
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(buffer, i)
            let planeWidth = CVPixelBufferGetWidthOfPlane(buffer, i)
            let planeHeight = CVPixelBufferGetHeightOfPlane(buffer, i)
            let bytesToCopy = planeWidth * (i + 1)
            for j in 0..<planeHeight {
                let planeBufferDeviation = bytesPerRow * j
                memcpy(bufferPointee, planeBuffer + planeBufferDeviation, bytesToCopy)
                bufferPointee = bufferPointee + bytesToCopy
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        
        guard let frame = VCVideoFrame(
            .format420f, buffer: finalBuffer,
            size: UInt32(finalSize),
            videoFrameIConstructFromKnownFormatWithExternalBuffer: self,
            width: UInt32(CVPixelBufferGetWidth(buffer)),
            height: UInt32( CVPixelBufferGetHeight(buffer))
        ) else {
            log.info("VCVideoFrame initialization failed")
            return
        }
        source.onFrame(frame, mediaFormat: .format420f)
    }
}

// MARK: - VCVideoFrameIConstructFromKnownFormatWithExternalBuffer
extension ScreenShareOutput: VCVideoFrameIConstructFromKnownFormatWithExternalBuffer {
    func releaseCallback(_ buffer: UnsafeMutableRawPointer!, size: Int) {
        free(buffer)
    }
}
