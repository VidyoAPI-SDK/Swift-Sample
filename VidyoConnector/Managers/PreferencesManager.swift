//
//  PreferencesManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 03.06.2021.
//

import Foundation

enum PreferencesOption {
    case mic
    case camera
    case speaker
}

class PreferencesManager {
      
    static let shared = PreferencesManager()
    
    var micState: DeviceState
    var cameraState: DeviceState
    var speakerState: DeviceState
    
    var devicesSelected: Bool
    var shouldUnmuteCameraOnForeground: Bool

    private init() {
        micState = .unmuted
        cameraState = .unmuted
        speakerState = .unmuted
        devicesSelected = true
        shouldUnmuteCameraOnForeground = false
    }
    
    func updateDisabledStates() {
        micState.enableIfNeeded()
        cameraState.enableIfNeeded()
    }
    
    func setState(for option: PreferencesOption, state: DeviceState) {
        switch option {
        case .mic: micState.setState(state)
        case .camera: cameraState.setState(state)
        case .speaker: speakerState.setState(state)
        }
    }
    
    func swapStates(for option: PreferencesOption) {
        switch option {
        case .mic: micState.swapBasicStates()
        case .camera: cameraState.swapBasicStates()
        case .speaker: speakerState.swapBasicStates()
        }
    }
    
    func handleStateUpdated(type: PreferencesOption, state: VCDeviceState) {
        let deviceState: DeviceState
        if state == .started || state == .resumed {
            deviceState = .unmuted
        } else if state == .stopped || state == .paused {
            deviceState = .muted
        } else {
            return
        }
        setState(for: type, state: deviceState)
    }
    
    func getCurrentState(of option: PreferencesOption) -> Bool {
        switch option {
        case .mic: return micState.bool
        case .camera: return cameraState.bool
        case .speaker: return speakerState.bool
        }
    }
    
    func getProperImageName(for option: PreferencesOption) -> String {
        var optionOff = String()
        let isOnCall: Bool = ConnectorManager.shared.connectionManager.connectionState.bool
        
        switch option {
        case .speaker:
            optionOff = isOnCall ? Constants.Icon.speakerMuted : Constants.Icon.speakerDisabled
            return speakerState == .unmuted ? Constants.Icon.speakerOn : optionOff
        case .mic:
            optionOff = (isOnCall && micState == .muted) ? Constants.Icon.micMuted : Constants.Icon.micDisabled
            return micState == .unmuted ? Constants.Icon.micOn : optionOff
        case .camera:
            optionOff = (isOnCall && cameraState == .muted) ? Constants.Icon.cameraMuted : Constants.Icon.cameraDisabled
            return cameraState == .unmuted ? Constants.Icon.cameraOn : optionOff
        }
    }
}
