//
//  AudioSettingsOptions.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 23.06.2021.
//

import Foundation
import VidyoClientIOS

enum AudioSettingsSectionHeaderTitle: String {
    case deviceSelection = "Device selection"
    case general = "General"
    case forwardErrorCorrection = "Forward Error Correction (FEC)"
}

enum AudioSettingsOption: String, CaseIterable {
    case microphone = "Microphone"
    case speaker = "Speaker"
    
    case audioCodePreference = "Audio Code Preference"
    case audioPacketInterval = "Audio Packet Interval"
    
    case packetLoss = "Packet Loss %"
    case bitRateMultiplier = "Bit Rate Multiplier"
    
    static var options = AudioSecondaryOptions()
}

struct AudioSecondaryOptions {
    private let audioSetting = DefaultValuesManager.shared.getAudioOptions()

    var microphone: [OptionToChoose]?
    var speaker: [OptionToChoose]?
    
    var audioCodePreference = [
        OptionToChoose(title: AudioCodePreference.opus.rawValue, isChosen: true),
        OptionToChoose(title: AudioCodePreference.speexRed.rawValue, isChosen: false)
    ]
    
    lazy var audioPacketInterval: [OptionToChoose] = {
        var options = [
            OptionToChoose(title: "20 ms", isChosen: false),
            OptionToChoose(title: "40 ms", isChosen: false)
        ]
        guard let audioPacketInterval = audioSetting?.audioPacketInterval else { return options }
        options = options.map {
            guard $0.title.digits == String(audioPacketInterval) else { return $0 }
            return OptionToChoose(title: $0.title, isChosen: true)
        }
        return options
    }()
    
    lazy var packetLoss: [OptionToChoose] = {
        var options = [
            OptionToChoose(title: "0", isChosen: false),
            OptionToChoose(title: "10", isChosen: false),
            OptionToChoose(title: "20", isChosen: false),
            OptionToChoose(title: "30", isChosen: false)
        ]
        guard let audioPacketLoss = audioSetting?.audioPacketLossPercentage else { return options }
        options = options.map {
            guard $0.title == String(audioPacketLoss) else { return $0 }
            return OptionToChoose(title: $0.title, isChosen: true)
        }
        return options
    }()
    
    lazy var bitRateMultiplier: [OptionToChoose] = {
        var options = [
            OptionToChoose(title: "0", isChosen: false),
            OptionToChoose(title: "1", isChosen: false),
            OptionToChoose(title: "2", isChosen: false)
        ]
        guard let audioBitrateMultiplier = audioSetting?.audioBitrateMultiplier else { return options }
        options = options.map {
            guard $0.title == String(audioBitrateMultiplier) else { return $0 }
            return OptionToChoose(title: $0.title, isChosen: true)
        }
        return options
    }()
    
    mutating func getMicrophoneOptions(with localMicrophones: SynchronizedArray<VCLocalMicrophone>, currentMicro: VCLocalMicrophone?) -> [OptionToChoose]? {
        guard microphone == nil else { return microphone }
        
        var options = [OptionToChoose]()
        localMicrophones.forEach { localMicro in
            if localMicro == currentMicro {
                options.append(OptionToChoose(title: localMicro.name as String, isChosen: true))
            } else {
                options.append(OptionToChoose(title: localMicro.name as String, isChosen: false))
            }
        }
        microphone = options
        return microphone
    }
    
    mutating func getSpeakerOptions(with localSpeakers: SynchronizedArray<VCLocalSpeaker>, currentSpeaker: VCLocalSpeaker?) -> [OptionToChoose]? {
        guard speaker == nil else { return speaker }
        
        var options = [OptionToChoose]()
        localSpeakers.forEach { localSpeaker in
            if localSpeaker == currentSpeaker {
                options.append(OptionToChoose(title: localSpeaker.name as String, isChosen: true))
            } else {
                options.append(OptionToChoose(title: localSpeaker.name as String, isChosen: false))
            }
        }
        speaker = options
        return speaker
    }
    
    func getChosenOptionTitle(from options: [OptionToChoose]) -> String {
        var title = String()
        options.forEach {
            if $0.isChosen {
                title = $0.title
            }
        }
        return title
    }
}
