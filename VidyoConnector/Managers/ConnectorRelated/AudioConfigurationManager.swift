//
//  AudioConfiguration.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 25.06.2021.
//

import Foundation
import VidyoClientIOS

class AudioConfigurationManager {
    enum AudioOptions: String {
        case codePreference = "preferredAudioCodec"
        case packetInterval = "AudioPacketInterval"
        case packetLoss = "AudioPacketLossPercentage"
        case bitRateMultiplier = "AudioBitrateMultiplier"
    }
    
    private let connector = ConnectorManager.shared.connector
    
    weak var delegate: LocalDeviceStateUpdatedDelegate?
    
    var localMicrophones = SynchronizedArray<VCLocalMicrophone>()
    var localSpeakers = SynchronizedArray<VCLocalSpeaker>()
    var currentLocalMicrophone: VCLocalMicrophone?
    var currentLocalSpeaker: VCLocalSpeaker?
    
    var isMicrophonesAvailableForSelecting: Bool {
        localMicrophones.count > 1
    }
    var isSpeakersAvailableForSelecting: Bool {
        localSpeakers.count > 1
    }
    
    init() {
        connector.registerLocalMicrophoneEventListener(self)
        connector.registerLocalSpeakerEventListener(self)
    }
    
    deinit {
        connector.unregisterLocalMicrophoneEventListener()
        connector.unregisterLocalSpeakerEventListener()
    }
    
    //MARK: - Audio Settings
    func setMicrophone(_ index: Int) -> Bool {
        guard index < localMicrophones.count else { return false }
        currentLocalMicrophone = localMicrophones[index]
        return connector.select(currentLocalMicrophone)
    }
    
    func setSpeaker(_ index: Int) -> Bool {
        guard index < localSpeakers.count else { return false }
        currentLocalSpeaker = localSpeakers[index]
        return connector.select(currentLocalSpeaker)
    }
    
    func setAudioCodePreference(value: String) -> Bool {
        set(option: .codePreference, asString: value)
    }
    
    func setAudioPacketInterval(value: String) -> Bool {
        set(option: .packetInterval, asNumber: value)
    }
    
    func setPacketLoss(value: String) -> Bool {
        set(option: .packetLoss, asNumber: value)
    }
    
    func setBitRateMultiplier(value: String) -> Bool {
        set(option: .bitRateMultiplier, asNumber: value)
    }
    
    private func set(option: AudioOptions, asString value: String) -> Bool {
        connector.setOptions("{\"\(option.rawValue)\" : \"\(value)\"}")
    }

    private func set(option: AudioOptions, asNumber value: String) -> Bool {
        connector.setOptions("{\"\(option.rawValue)\" : \(value)}")
    }
    
    private func removeLocalMicrophone(_ microphone: VCLocalMicrophone) {
        localMicrophones = localMicrophones.filter { $0 != microphone }
        if currentLocalMicrophone == microphone {
            currentLocalMicrophone = localMicrophones.first
            connector.select(currentLocalMicrophone)
        }
    }
    
    private func removeLocalSpeaker(_ speaker: VCLocalSpeaker) {
        localSpeakers = localSpeakers.filter { $0 != speaker }
        if currentLocalSpeaker == speaker {
            currentLocalSpeaker = localSpeakers.first
            connector.select(currentLocalSpeaker)
        }
    }

    /// Demo: in-band DTMF via microphone + local speaker feedback (same pattern as Android Kotlin sample).
    func playDtmfDemo(tones: String = "123#", intervalSeconds: TimeInterval = 0.25) {
        log.info("DTMF demo: sending tones='\(tones)' (speaker+microphone)")
        var delay: TimeInterval = 0
        for ch in tones {
            guard !ch.isWhitespace else { continue }
            let toneChar = ch
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                let c = Self.cChar(for: toneChar)
                if let speaker = self.currentLocalSpeaker {
                    log.info("DTMF: VCLocalSpeaker playTone('\(toneChar)')")
                    speaker.playTone(c)
                }
                if let microphone = self.currentLocalMicrophone {
                    log.info("DTMF: VCLocalMicrophone playTone('\(toneChar)')")
                    microphone.playTone(c)
                }
            }
            delay += intervalSeconds
        }
    }

    private static func cChar(for character: Character) -> Int8 {
        let s = String(character)
        guard let byte = s.utf8.first else { return 0 }
        return Int8(bitPattern: byte)
    }
}

//MARK: - VCConnectorIRegisterLocalMicrophoneEventListener
extension AudioConfigurationManager: VCConnectorIRegisterLocalMicrophoneEventListener {
    func onLocalMicrophoneAdded(_ localMicrophone: VCLocalMicrophone!) {
        localMicrophones.append(localMicrophone)
    }
    
    func onLocalMicrophoneRemoved(_ localMicrophone: VCLocalMicrophone!) {
        removeLocalMicrophone(localMicrophone)
    }
    
    func onLocalMicrophoneSelected(_ localMicrophone: VCLocalMicrophone!) {
        currentLocalMicrophone = localMicrophone
    }
    
    func onLocalMicrophoneStateUpdated(_ localMicrophone: VCLocalMicrophone!, state: VCDeviceState) {
        delegate?.onLocalDeviceStateUpdated(type: .mic, state: state)
    }
}

//MARK: - VCConnectorIRegisterLocalSpeakerEventListener
extension AudioConfigurationManager: VCConnectorIRegisterLocalSpeakerEventListener {
    func onLocalSpeakerAdded(_ localSpeaker: VCLocalSpeaker!) {
        localSpeakers.append(localSpeaker)
    }
    
    func onLocalSpeakerRemoved(_ localSpeaker: VCLocalSpeaker!) {
        removeLocalSpeaker(localSpeaker)
    }
    
    func onLocalSpeakerSelected(_ localSpeaker: VCLocalSpeaker!) {
        currentLocalSpeaker = localSpeaker
    }
    
    func onLocalSpeakerStateUpdated(_ localSpeaker: VCLocalSpeaker!, state: VCDeviceState) {
        delegate?.onLocalDeviceStateUpdated(type: .speaker, state: state)
    }
}
