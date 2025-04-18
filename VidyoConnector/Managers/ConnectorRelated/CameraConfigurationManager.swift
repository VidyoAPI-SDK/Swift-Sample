//
//  CameraConfigurationManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 25.06.2021.
//

import Foundation
import VidyoClientIOS

class CameraConfigurationManager {
    
    static let shared = CameraConfigurationManager()
    private let connector = ConnectorManager.shared.connector
    private var currentLocalCameraWidth: UInt32 = Constants.DefaultCameraConstraint.width
    private var currentLocalCameraHeight: UInt32 = Constants.DefaultCameraConstraint.height
    private var currentLocalCameraFrameRate: Int = Constants.DefaultCameraConstraint.frameRate
    
    weak var delegate: LocalDeviceStateUpdatedDelegate?
    
    var localCameraOptions = SynchronizedArray<VCLocalCamera>()
    var currentLocalCamera: VCLocalCamera?
    var isCameraAvailableForSelecting: Bool {
        localCameraOptions.count > 1
    }
    
    init() {
        connector.registerLocalCameraEventListener(self)
    }
    
    deinit {
        connector.unregisterLocalCameraEventListener()
    }

    //MARK: - General settings
    func setCPUProfile(_ value: CPUProfileOption) -> Bool {
        switch value {
        case .high:
            return connector.setCpuTradeOffProfile(.high)
        case .medium:
            return connector.setCpuTradeOffProfile(.medium)
        case .low:
            return connector.setCpuTradeOffProfile(.low)
        }
    }
    
    //MARK: - Video Settings
    func setCamera(_ index: Int) -> Bool {
        guard index < localCameraOptions.count else { return false }
        currentLocalCamera = localCameraOptions[index]
        return connector.select(currentLocalCamera)
    }
    
    func setCameraResolution(width: UInt32, height: UInt32) -> Bool {
        guard let currentLocalCamera = currentLocalCamera else { return false }
        let frameInterval = nanosecondInterval(fps: currentLocalCameraFrameRate)
        let isFrameRateSet = currentLocalCamera.setMaxConstraint(
            width,
            height: height,
            frameInterval: frameInterval
        )
        guard isFrameRateSet else { return false }
        currentLocalCameraWidth = width
        currentLocalCameraHeight = height
        return isFrameRateSet
    }
    
    func setFrameRate(_ frameRate: Int) -> Bool {
        guard let currentLocalCamera = currentLocalCamera else { return false }
        let frameInterval = nanosecondInterval(fps: frameRate)
        let isFrameRateSet = currentLocalCamera.setMaxConstraint(
            currentLocalCameraWidth,
            height: currentLocalCameraHeight,
            frameInterval: frameInterval
        )
        guard isFrameRateSet else { return false }
        currentLocalCameraFrameRate = frameRate
        return isFrameRateSet
    }
    
    func disableVideoOnPoorConnection(withValue enable: Bool) -> Bool {
        connector.setDisableVideoOnLowBandwidth(enable)
    }
    
    func setDisableVideoOnLowBandwidthResponseTime(_ responseTime: UInt32) -> Bool {
        connector.setDisableVideoOnLowBandwidthResponseTime(responseTime)
    }
    
    func setDisableVideoOnLowBandwidthSampleTime(_ sampleTime: UInt32) -> Bool {
        connector.setDisableVideoOnLowBandwidthSampleTime(sampleTime)
    }
    
    func setDisableVideoOnLowBandwidthThreshold(_ kbps: UInt32) -> Bool {
        connector.setDisableVideoOnLowBandwidthThreshold(kbps)
    }
    
    func setDisableVideoOnLowBandwidthAudioStreams(_ audioStreams: UInt32) -> Bool {
        connector.setDisableVideoOnLowBandwidthAudioStreams(audioStreams)
    }
    
    func setMaxSendBitRate(_ bitRate: UInt32) -> Bool {
        connector.setMaxSendBitRate(bitRate)
    }
    
    func setMaxReceiveBitRate(_ bitRate: UInt32) -> Bool {
        connector.setMaxReceiveBitRate(bitRate)
    }
    
    private func removeLocalCamera(_ camera: VCLocalCamera) {
        localCameraOptions = localCameraOptions.filter { $0 != camera }
        if currentLocalCamera == camera {
            currentLocalCamera = localCameraOptions.first
            connector.select(currentLocalCamera)
        }
    }
    
    private func nanosecondInterval(fps: Int) -> Int {
        1000000000/fps
    }
    
    public func updateTorchStatus() {
        var state: DeviceState = .disabled;
        
        if currentLocalCamera == nil || currentLocalCamera?.hasTorch() == false{
            delegate?.onOtherDeviceStateUpdated(type: .torch, state: state)
            return;
        }
        
        switch currentLocalCamera?.getTorchMode() {
        case .LOCALCAMERA_TORCHMODE_None : state = .disabled
        case .LOCALCAMERA_TORCHMODE_On: state = .on
        case .LOCALCAMERA_TORCHMODE_Off: state = .off
        default:
            break;
        }
        
        delegate?.onOtherDeviceStateUpdated(type: .torch, state: state)
    }
    
    public func setTorchMode(isMute: Bool) {
        var mode:VCLocalCameraTorchMode = VCLocalCameraTorchMode.LOCALCAMERA_TORCHMODE_None;
        
        if currentLocalCamera == nil || currentLocalCamera?.hasTorch() == false{
            return;
        }
        
        switch(isMute) {
        case true : mode = VCLocalCameraTorchMode.LOCALCAMERA_TORCHMODE_Off;
        case false : mode = VCLocalCameraTorchMode.LOCALCAMERA_TORCHMODE_On;
        }
        
        currentLocalCamera?.setTorchMode(mode);
    }
}

//MARK: - VCConnectorIRegisterLocalCameraEventListener
extension CameraConfigurationManager: VCConnectorIRegisterLocalCameraEventListener {
    func onLocalCameraAdded(_ localCamera: VCLocalCamera!) {
        localCameraOptions.append(localCamera)
        updateTorchStatus();
    }
    
    func onLocalCameraRemoved(_ localCamera: VCLocalCamera!) {
        removeLocalCamera(localCamera)
        updateTorchStatus();
    }
    
    func onLocalCameraSelected(_ localCamera: VCLocalCamera!) {
        currentLocalCamera = localCamera
        updateTorchStatus();
    }
    
    func onLocalCameraStateUpdated(_ localCamera: VCLocalCamera!, state: VCDeviceState) {
        delegate?.onLocalDeviceStateUpdated(type: .camera, state: state)
        updateTorchStatus();
    }
}
