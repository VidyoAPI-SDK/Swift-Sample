//
//  VirtualVideoSourceManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 30.07.2021.
//

import Foundation

class VirtualVideoSourceManager {
    let connector = ConnectorManager.shared.connector
    
    private let id = "ScreenShare-" + UUID().uuidString
    private let name = "VidyoConnectoriOS"
    
    private var source: VCVirtualVideoSource?
    private var sources = [VCVirtualVideoSource]()
    
    var onStartHandler: ((Int, VCMediaFormat) -> ())?
    var onStopHandler: (() -> ())?
    var onReconfigureHandler: ((Int, VCMediaFormat) -> ())?
    
    init() {
        connector.registerVirtualVideoSourceEventListener(self)
        connector.createVirtualVideoSource(.SHARE, id: id, name: name)
    }
    
    deinit {
        connector.unregisterVirtualVideoSourceEventListener()
    }
    
    func getVirtualVideoSource() -> VCVirtualVideoSource? {
        guard source == nil else { return source }
        source = sources.first(where: { $0.getId() == id })
        return source
    }
    
    func selectVirtualSourceWindowShare(_ source: VCVirtualVideoSource?)  {
        connector.selectVirtualSourceWindowShare(source)
    }
}

//MARK: - VCConnectorIRegisterVirtualVideoSourceEventListener
extension VirtualVideoSourceManager: VCConnectorIRegisterVirtualVideoSourceEventListener {
    func onVirtualVideoSourceAdded(_ virtualVideoSource: VCVirtualVideoSource!) {
        sources.append(virtualVideoSource)
    }
    
    func onVirtualVideoSourceRemoved(_ virtualVideoSource: VCVirtualVideoSource!) {
        guard let indexToRemove = sources.firstIndex(of: virtualVideoSource) else { return }
        sources.remove(at: indexToRemove)
        guard source == virtualVideoSource else { return }
        source = nil
    }
    
    func onVirtualVideoSourceStateUpdated(_ virtualVideoSource: VCVirtualVideoSource!, state: VCDeviceState) {
        let frameInterval = virtualVideoSource.getCurrentEncodeFrameInterval()
        let mediaFormat = virtualVideoSource.getMediaType()
        
        switch state {
        case .started:
            onStartHandler?(frameInterval, mediaFormat)
        case .stopped:
            onStopHandler?()
        case .configurationChanged:
            onReconfigureHandler?(frameInterval, mediaFormat)
        default: return
        }
    }
    
    func onVirtualVideoSourceExternalMediaBufferReleased(_ virtualVideoSource: VCVirtualVideoSource!, buffer: UnsafeMutablePointer<UInt8>!, size: Int) {
        free(buffer)
    }
}

//MARK: - VCVirtualVideoSourceExtension
extension VCVirtualVideoSource {
    func set(maxConstraints: ScreenShareOutputMaxConstraints) {
        log.info("\(maxConstraints.description)")
        setMaxConstraints(UInt32(maxConstraints.maxSize.width),
                          height: UInt32(maxConstraints.maxSize.height),
                          frameInterval: UnitsConversion.frameInterval(fps: maxConstraints.maxFPS))
    }
}
