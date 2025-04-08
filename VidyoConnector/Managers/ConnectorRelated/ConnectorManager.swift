//
//  ConnectorManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 29.05.2021.
//

import Foundation
import VidyoClientIOS

class ConnectorManager {
      
    static let shared = ConnectorManager()
    
    private(set) var connector: VCConnector
    private var preferences = PreferencesManager.shared
    lazy var connectionManager = ConnectionHandlingManager()
    lazy var participantManager = ParticipantsManager()
    public var participantsNumber: UInt32
    
    var version: String {
        connector.getVersion()
    }
    
    private init() {
        participantsNumber = 5
        connector = VCConnector(
            nil,
            viewStyle: .default,
            remoteParticipants: participantsNumber,
            logFileFilter: "".cString(using: .utf8),
            logFileName: "\(Constants.LogsFile.pathString)/\(Constants.LogsFile.name)",
            userData: 0
        )

        let certificates = CertificatesManager.getDefaultCertificates()
        if (!certificates.isEmpty && !connector.setCertificateAuthorityList(certificates.cString(using: .utf8))) {
            log.info("Failed to set certificate authority list")
        }
    }
    
    func changeDevicePrivacy(forOption option: PreferencesOption, specificState: Bool? = nil) {
        let isMuted: Bool = specificState ?? !preferences.getCurrentState(of: option)        
        switch option {
        case .speaker:
            guard connector.setSpeakerPrivacy(isMuted) else { return }
            preferences.swapStates(for: .speaker)
        case .mic:
            guard connector.setMicrophonePrivacy(isMuted) else { return }
            preferences.swapStates(for: .mic)
        case .camera:
            guard connector.setCameraPrivacy(isMuted) else { return }
            preferences.swapStates(for: .camera)
        case .torch:
            preferences.swapStates(for: .torch)
            CameraConfigurationManager.shared.setTorchMode(isMute: isMuted)
            break;
        }
    }
    
    func setCameraBackgroundEffect(_ effectType: VCConnectorCameraEffectType, picturePath: String = "") -> Bool {
        let virtualBackgroundPicturePath = NSMutableString(utf8String: picturePath)
        
        let info = VCConnectorCameraEffectInfo()
        info.effectType = effectType
        
        switch (effectType) {
        case .blur:
            info.token = BackgroundResoursesConstants.token
            info.pathToResources = BackgroundResoursesConstants.pathToResources
            info.pathToEffect = BackgroundResoursesConstants.blurPathToEffect
            info.virtualBackgroundPicture = virtualBackgroundPicturePath
            info.blurIntensity = 5
        case .virtualBackground:
            info.token = BackgroundResoursesConstants.token
            info.pathToResources = BackgroundResoursesConstants.pathToResources
            info.pathToEffect = BackgroundResoursesConstants.virtualBackgroundPath
            info.virtualBackgroundPicture = virtualBackgroundPicturePath
        case .none:
            info.token = ""
            info.pathToResources = ""
            info.pathToEffect = ""
            info.virtualBackgroundPicture = ""
        default: break
        }
        
        return connector.setCameraBackgroundEffect(info)
    }
    
    func setVirtualBackgroundPicture(picturePath: String) -> Bool {
        connector.setVirtualBackgroundPicture(picturePath)
    }
    
    func disable() {
        connectionManager.connectionState = .disconnected
        connector.disable()
    }
    
    func handleBackground() {
        let noMic: VCLocalMicrophone? = nil
        let noSpeaker: VCLocalSpeaker? = nil
        let isCameraMuted = preferences.getCurrentState(of: .camera)
        
        if connectionManager.connectionState == .connected {
            if !isCameraMuted {
                preferences.shouldUnmuteCameraOnForeground = true
                changeDevicePrivacy(forOption: .camera)
            }
        } else {
            connector.select(noMic)
            connector.select(noSpeaker)
            preferences.devicesSelected = false
        }
        connectionManager.connector.setMode(.background)
    }
    
    func handleForeground() {
        connectionManager.connector.setMode(.foreground)
        if preferences.shouldUnmuteCameraOnForeground {
            preferences.shouldUnmuteCameraOnForeground = false
            changeDevicePrivacy(forOption: .camera)
        }
        guard !preferences.devicesSelected else { return }
        connector.selectDefaultSpeaker()
        connector.selectDefaultMicrophone()
    }
}
