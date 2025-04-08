//
//  PreferencesManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 03.06.2021.
//

import Foundation
import VidyoClientIOS

enum PreferencesOption {
    case mic
    case camera
    case speaker
    case torch
}

class PreferencesManager {
      
    static let shared = PreferencesManager()
    
    var micState: DeviceState
    var cameraState: DeviceState
    var speakerState: DeviceState
    var torchState: DeviceState
    
    var devicesSelected: Bool
    var shouldUnmuteCameraOnForeground: Bool

    private init() {
        micState = .unmuted
        cameraState = .unmuted
        speakerState = .unmuted
        torchState = .off
        devicesSelected = true
        shouldUnmuteCameraOnForeground = false
    }
    
    func updateDisabledStates() {
        speakerState.enableIfNeeded()
        micState.enableIfNeeded()
        cameraState.enableIfNeeded()
    }
    
    func setState(for option: PreferencesOption, state: DeviceState) {
        switch option {
        case .mic: micState.setState(state)
        case .camera: cameraState.setState(state)
        case .speaker: speakerState.setState(state)
        case .torch: torchState.setState(state)
        }
    }
    
    func swapStates(for option: PreferencesOption) {
        switch option {
        case .mic: micState.swapBasicStates()
        case .camera: cameraState.swapBasicStates()
        case .speaker: speakerState.swapBasicStates()
        case .torch: torchState.swapBasicStates()
        }
    }
    
    func handleStateUpdated(type: PreferencesOption, state: VCDeviceState) {
        let deviceState: DeviceState
        if state == .resumed {
            deviceState = .unmuted
        } else if state == .paused {
            deviceState = .muted
        } else {
            return
        }
        setState(for: type, state: deviceState)
    }
    
    func handleTorchState(type: PreferencesOption, state : DeviceState) {
        setState(for: type, state: state)
    }
    
    func getCurrentState(of option: PreferencesOption) -> Bool {
        switch option {
        case .mic: return micState.bool
        case .camera: return cameraState.bool
        case .speaker: return speakerState.bool
        case .torch: return torchState.bool
        }
    }
    
    func getProperImageName(for option: PreferencesOption) -> String {
        switch option {
        case .speaker:
            return speakerState == .unmuted ? Constants.Icon.speakerOn : (speakerState == .disabled ? Constants.Icon.speakerDisabled : Constants.Icon.speakerMuted)
        case .mic:
            return micState == .unmuted ? Constants.Icon.micOn : (micState == .disabled ? Constants.Icon.micDisabled : Constants.Icon.micMuted)
        case .camera:
            return cameraState == .unmuted ? Constants.Icon.cameraOn : (cameraState == .disabled ? Constants.Icon.cameraDisabled : Constants.Icon.cameraMuted)
        case .torch:
            return torchState == .on ? Constants.Icon.torchOn : (torchState == .disabled ? Constants.Icon.torchDisabled : Constants.Icon.torchOff)
        }
    }
}
