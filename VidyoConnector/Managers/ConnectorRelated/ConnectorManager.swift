//
//  ConnectorManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 29.05.2021.
//

import Foundation
import DevicePpi

class ConnectorManager {
      
    static let shared = ConnectorManager()
    
    private(set) var connector: VCConnector
    private var preferences = PreferencesManager.shared
    lazy var connectionManager = ConnectionHandlingManager()
    lazy var participantManager = ParticipantsManager()
    var participantsNumber: UInt32
    
    var version: String {
        connector.getVersion()
    }
    
    private init() {
        var defaultView: UIView?
        participantsNumber = 5
        connector = VCConnector(
            &defaultView,
            viewStyle: .default,
            remoteParticipants: participantsNumber,
            logFileFilter: "".cString(using: .utf8),
            logFileName: "\(Constants.LogsFile.pathString)/\(Constants.LogsFile.name)",
            userData: 0
        )
    }
    
    func getDevicePpi() -> Double{
        let ppi: Double = {
            switch Ppi.get() {
                case .success(let ppi):
                     return ppi
                case .unknown(let bestGuessPpi, _):
                     // A bestGuessPpi value is provided but may be incorrect
                     // Treat as a non-fatal error -- e.g. log to your backend and/or display a message
                     return bestGuessPpi
                }
            }()
        return ppi;
	}

    func assignView(_ view: inout UIView, remoteParticipants: UInt32? = nil) {
        let participants: UInt32 = remoteParticipants ?? participantsNumber
        connector.assignView(
            toCompositeRenderer: &view,
            viewStyle: .default,
            remoteParticipants: participants
        )
        
        var option = "{\"SetPixelDensity\":";
        option.append("\(getDevicePpi() )");
        option.append(",\"ViewingDistance\":1.0}");
        
        if(connector.setRendererOptionsForViewId(&view, options:option) == false) {
            log.info("Failed to set renderer option for view id")
        }
    }
    
    func showLabel(_ showLabel: Bool, for videoView: inout UIView) {
        connector.showViewLabel(&videoView, showLabel: showLabel)
    }
    
    func showView(for videoView: inout UIView) {
        connector.showView(
            at: &videoView,
            x: 0,
            y: 0,
            width: UInt32(videoView.frame.size.width),
            height: UInt32(videoView.frame.size.height)
        )
    }
    
    func showAudioMeters(_ showMeters: Bool, for videoView: inout UIView) {
        connector.showAudioMeters(&videoView, showMeters: showMeters)
    }
    
    func hideView(_ videoView: inout UIView) {
        connector.hideView(&videoView)
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
