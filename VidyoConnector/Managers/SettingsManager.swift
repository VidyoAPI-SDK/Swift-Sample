//
//  SettingsManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 14.06.2021.
//

import Foundation

protocol LocalDeviceStateUpdatedDelegate: AnyObject {
    func onLocalDeviceStateUpdated(type: PreferencesOption, state: VCDeviceState)
}

class SettingsManager {
    
    static let shared = SettingsManager()
    
    private let cameraConfiguration = CameraConfigurationManager()
    private let audioConfiguration = AudioConfigurationManager()
    private let networkManager = NetworkInterfaceManager()
    
    let analyticsManager = AnalyticsManager()
    let logsManager = LogsManager()

    private lazy var mainSettingsOptions = [
        SettingsOptionCell(title: .general, iconName: Constants.Icon.general, isEnabled: true),
        SettingsOptionCell(title: .audio, iconName: Constants.Icon.audio, isEnabled: true),
        SettingsOptionCell(title: .video, iconName: Constants.Icon.video, isEnabled: true),
        SettingsOptionCell(title: .account, iconName: Constants.Icon.accountDisabled, isEnabled: false),
        SettingsOptionCell(title: .logs, iconName: Constants.Icon.logs, isEnabled: true),
        SettingsOptionCell(title: .about, iconName: Constants.Icon.info, isEnabled: true),
        SettingsOptionCell(title: .help, iconName: Constants.Icon.help, isEnabled: true)
    ]
    
    private lazy var generalData = [SettingsSection]()
    private lazy var audioData = [SettingsSection]()
    private lazy var videoData = [SettingsSection]()
    
    private var isOptionEnableDuringCall: Bool {
        switch ConnectorManager.shared.connectionManager.connectionState {
        case .connected: return true
        case .disconnected: return false
        }
    }
    
    private init() {}
    
    // MARK: - Functions
    func setDelegate(_ delegate: LocalDeviceStateUpdatedDelegate) {
        audioConfiguration.delegate = delegate
    }
    
    func getMainOptinsData() -> [SettingsOptionCell] {
        return mainSettingsOptions
    }
    
    func getSettingsTableViewData(forChoice option: SettingsOption) -> [SettingsSection]? {
        switch option {
        case .general:
            return generalData
        case .audio:
            return audioData
        case .video:
            return videoData
        default:
            return nil
        }
    }
    
    func getOptionsToChoose(forChoice option: SettingsOption, title: String) -> [OptionToChoose]? {
        switch option {
        case .general:
            guard let optionType = GeneralSettingsOption(rawValue: title) else { return nil }
            return getGeneralOptionsToChoose(forCase: optionType)
        case .audio:
            guard let optionType = AudioSettingsOption(rawValue: title) else { return nil }
            return getAudioOptionsToChoose(forCase: optionType)
        case .video:
            guard let optionType = VideoSettingsOption(rawValue: title) else { return nil }
            return getVideoOptionsToChoose(forCase: optionType)
        default:
            return nil
        }
    }
    
    func getDefaultValue(forChoice option: SettingsOption, title: String) -> UInt32? {
        switch option {
        case .video:
            guard let optionType = VideoSettingsOption(rawValue: title) else { return nil }
            return VideoSettingsOption.options.getDefaultValue(forOption: optionType)
        default:
            return nil
        }
    }
    
    func setNewValuesIfPossible(forType settingsType: SettingsOption, forCase title: String, withArray array: [OptionToChoose], optionIndex: Int) -> Bool {
        switch settingsType {
        case .general:
            guard let optionType = GeneralSettingsOption(rawValue: title) else { return false }
            return setNewValuesForGeneralIfPossible(array, optionIndex: optionIndex, forCase: optionType)
        case .audio:
            guard let optionType = AudioSettingsOption(rawValue: title) else { return false }
            return setNewValuesForAudioIfPossible(array, optionIndex: optionIndex, forCase: optionType)
        case .video:
            guard let optionType = VideoSettingsOption(rawValue: title) else { return false }
            return setNewValuesForVideoIfPossible(array, optionIndex: optionIndex, forCase: optionType)
        case .logs:
            return setNewLogLevelIfPossible(array, optionIndex: optionIndex)
        default:
            return false
        }
    }
    
    func setSwitchValueIfPossible(_ isOn: Bool, forCase option: SettingsSwitchCell) -> Bool {
        switch option {
        case .autoReconnect:
            guard ConnectorManager.shared.connectionManager.enableAutoReconnect(withValue: isOn) else { return false }
            GeneralSettingsOption.options.switchToggle(forTitle: .autoReconnect, withValue: isOn)
        case .disableVideoOnPoorConnection:
            guard cameraConfiguration.disableVideoOnPoorConnection(withValue: isOn) else { return false }
            VideoSettingsOption.options.switchToggle(forTitle: .disableVideoOnPoorConnection, withValue: isOn)
        }
        return true
    }
    
    func updateSettingsTableViewData(forChoice option: SettingsOption) {
        switch option {
        case .general:
            updateGeneralSettingsData()
        case .audio:
            updateAudioSettingsData()
        case .video:
            updateVideoSettingsData()
        default: return
        }
    }
    
    //MARK: - Manage Logs
    private func setNewLogLevelIfPossible(_ array: [OptionToChoose], optionIndex: Int) -> Bool {
        guard let logLevel = LogLevel(rawValue: array[optionIndex].title) else { return false }
        let isSuccessfullySetLogLevel = logsManager.setLogLevel(logLevel)
        guard isSuccessfullySetLogLevel else { return false }
        LogLevelOptions.options = array
        return isSuccessfullySetLogLevel
    }
    
    //MARK: - Manage General Settings
    private func getGeneralOptionsToChoose(forCase option: GeneralSettingsOption) -> [OptionToChoose]? {
        switch option {
        case .cpuProfile:
            return GeneralSettingsOption.options.cpuProfile
        case .networkSignaling:
            return GeneralSettingsOption.options.getNetworkSignaling(with: networkManager.networkInterfaces, networkManager.currentNetworkSignaling)
        case .networkMedia:
            return GeneralSettingsOption.options.getNetworkMedia(with: networkManager.networkInterfaces, networkManager.currentNetworkMedia)
        case .participants:
            return GeneralSettingsOption.options.participants
        case .selfView:
            return GeneralSettingsOption.options.selfView
        case .reconnectAttempts:
            return GeneralSettingsOption.options.reconnectAttempts
        case .reconnectBackTime:
            return GeneralSettingsOption.options.reconnectBackTime
        default:
            return nil
        }
    }
    
    private func setNewValuesForGeneralIfPossible(_ array: [OptionToChoose], optionIndex: Int, forCase optionType: GeneralSettingsOption) -> Bool {
        switch optionType {
        case .cpuProfile:
            guard let cpuProfile = CPUProfileOption(rawValue: array[optionIndex].title) else { return false }
            guard cameraConfiguration.setCPUProfile(cpuProfile) else { return false }
            GeneralSettingsOption.options.cpuProfile = array
            
        case .networkSignaling:
            guard networkManager.setNetworkForSignaling(networkNumber: optionIndex) else { return false }
            GeneralSettingsOption.options.networkSignaling = array
               
        case .networkMedia:
            guard networkManager.setNetworkForSignaling(networkNumber: optionIndex) else { return false }
            GeneralSettingsOption.options.networkMedia = array
            
        case .participants:
            guard let numberToSet = UInt32(array[optionIndex].title.digits) else { return false }
            ConnectorManager.shared.participantsNumber = numberToSet
            GeneralSettingsOption.options.participants = array
            
        case .selfView:
            GeneralSettingsOption.options.selfView = array
            
        case .reconnectAttempts:
            guard let numberToSet = UInt32(array[optionIndex].title.digits) else { return false }
            guard ConnectorManager.shared.connectionManager.setAutoReconnectMaxAttempts(numberToSet) else { return false }
            GeneralSettingsOption.options.reconnectAttempts = array
            
        case .reconnectBackTime:
            guard let numberToSet = UInt32(array[optionIndex].title.digits) else { return false }
            guard ConnectorManager.shared.connectionManager.setAutoReconnectAttemptBackOff(numberToSet) else { return false }
            GeneralSettingsOption.options.reconnectBackTime = array
            
        default:
            return false
        }
        return true
    }
    
    private func updateGeneralSettingsData() {
        // Set General section
        let networksForSignaling = GeneralSettingsOption.options.getNetworkSignaling(with: networkManager.networkInterfaces, networkManager.currentNetworkSignaling) ?? [OptionToChoose]()
        let networksForMedia = GeneralSettingsOption.options.getNetworkMedia(with: networkManager.networkInterfaces, networkManager.currentNetworkMedia) ?? [OptionToChoose]()
        
        generalData = [
            SettingsSection(headerTitle: .general, options: [
                ChooseOptionCell(accessType: .chose, title: GeneralSettingsOption.cpuProfile.rawValue, options: GeneralSettingsOption.options.cpuProfile, isEnabled: !isOptionEnableDuringCall),
                ChooseOptionCell(accessType: .chose, title: GeneralSettingsOption.networkSignaling.rawValue, options: networksForSignaling, isEnabled: !isOptionEnableDuringCall),
                ChooseOptionCell(accessType: .chose, title: GeneralSettingsOption.networkMedia.rawValue, options: networksForMedia, isEnabled: !isOptionEnableDuringCall),
                ChooseOptionCell(accessType: .pick, title: GeneralSettingsOption.participants.rawValue, options: GeneralSettingsOption.options.participants, isEnabled: true),
                ChooseOptionCell(accessType: .chose, title: GeneralSettingsOption.selfView.rawValue, options: GeneralSettingsOption.options.selfView, isEnabled: false)
            ])
        ]
        // Append Auto Reconnect section
        if GeneralSettingsOption.options.isSwitchOn(forTitle: GeneralSettingsOption.enableAutoReconnect.rawValue) {
            generalData.append(
                SettingsSection(headerTitle: .autoRecconect, options: [
                    ChooseOptionCell(accessType: .toggle, title: GeneralSettingsOption.enableAutoReconnect.rawValue, options: GeneralSettingsOption.options.autoReconnectEnabled, isEnabled: !isOptionEnableDuringCall),
                    ChooseOptionCell(accessType: .pick, title: GeneralSettingsOption.reconnectAttempts.rawValue, options: GeneralSettingsOption.options.reconnectAttempts, isEnabled: !isOptionEnableDuringCall),
                    ChooseOptionCell(accessType: .pick, title: GeneralSettingsOption.reconnectBackTime.rawValue, options: GeneralSettingsOption.options.reconnectBackTime, isEnabled: !isOptionEnableDuringCall)
                ])
            )
        } else {
            generalData.append(
                SettingsSection(headerTitle: .autoRecconect, options: [
                    ChooseOptionCell(accessType: .toggle, title: GeneralSettingsOption.enableAutoReconnect.rawValue, options: GeneralSettingsOption.options.autoReconnectEnabled, isEnabled: !isOptionEnableDuringCall)
                ])
            )
        }
        generalData.append(
            SettingsSection(headerTitle: .googleAnalytics, options: [
            ChooseOptionCell(accessType: .googleAnalitycs, title: GeneralSettingsOption.googleAnalitycs.rawValue, options: GeneralSettingsOption.options.analitycs, isEnabled: !isOptionEnableDuringCall)
        ]))
        generalData.append(
            SettingsSection(headerTitle: .vidyoInsight, options: [
            ChooseOptionCell(accessType: .vidyoInsight, title: GeneralSettingsOption.vidyoInsight.rawValue, options: GeneralSettingsOption.options.analitycs, isEnabled: !isOptionEnableDuringCall)
        ]))
    }
    
    //MARK: - Manage Audio Settings
    private func getAudioOptionsToChoose(forCase option: AudioSettingsOption) -> [OptionToChoose]? {
        switch option {
        case .microphone:
            return AudioSettingsOption.options.getMicrophoneOptions(with: audioConfiguration.localMicrophones, currentMicro: audioConfiguration.currentLocalMicrophone)
        case .speaker:
            return AudioSettingsOption.options.getSpeakerOptions(with: audioConfiguration.localSpeakers, currentSpeaker: audioConfiguration.currentLocalSpeaker)
        case .audioCodePreference:
            return AudioSettingsOption.options.audioCodePreference
        case .audioPacketInterval:
            return AudioSettingsOption.options.audioPacketInterval
        case .packetLoss:
            return AudioSettingsOption.options.packetLoss
        case .bitRateMultiplier:
            return AudioSettingsOption.options.bitRateMultiplier
        }
    }
    
    private func setNewValuesForAudioIfPossible(_ array: [OptionToChoose], optionIndex: Int, forCase optionType: AudioSettingsOption) -> Bool {
        switch optionType {
        case .microphone:
            guard audioConfiguration.setMicrophone(optionIndex) else { return false }
            AudioSettingsOption.options.microphone = array
            
        case .speaker:
            guard audioConfiguration.setSpeaker(optionIndex) else { return false }
            AudioSettingsOption.options.speaker = array
               
        case .audioCodePreference:
            guard audioConfiguration.setAudioCodePreference(value: array[optionIndex].title) else { return false }
            AudioSettingsOption.options.audioCodePreference = array
            
        case .audioPacketInterval:
            let valueToSet = array[optionIndex].title.digits
            guard audioConfiguration.setAudioPacketInterval(value: valueToSet) else { return false }
            AudioSettingsOption.options.audioPacketInterval = array
            
        case .packetLoss:
            guard audioConfiguration.setPacketLoss(value: array[optionIndex].title) else { return false }
            AudioSettingsOption.options.packetLoss = array
            
        case .bitRateMultiplier:
            guard audioConfiguration.setBitRateMultiplier(value: array[optionIndex].title) else { return false }
            AudioSettingsOption.options.bitRateMultiplier = array
        }
        return true
    }

    private func updateAudioSettingsData() {
        let microOptions = AudioSettingsOption.options.getMicrophoneOptions(with: audioConfiguration.localMicrophones, currentMicro: audioConfiguration.currentLocalMicrophone) ?? [OptionToChoose]()
        let speakerOptions = AudioSettingsOption.options.getSpeakerOptions(with: audioConfiguration.localSpeakers, currentSpeaker: audioConfiguration.currentLocalSpeaker) ?? [OptionToChoose]()
        
        audioData = [
            SettingsSection(headerTitle: .deviceSelection, options: [
                ChooseOptionCell(accessType: .chose, title: AudioSettingsOption.microphone.rawValue, options: microOptions, isEnabled: audioConfiguration.isMicrophonesAvailableForSelecting),
                ChooseOptionCell(accessType: .chose, title: AudioSettingsOption.speaker.rawValue, options: speakerOptions, isEnabled: audioConfiguration.isSpeakersAvailableForSelecting)
            ]),
            SettingsSection(headerTitle: .general, options: [
                ChooseOptionCell(accessType: .chose, title: AudioSettingsOption.audioCodePreference.rawValue, options: AudioSettingsOption.options.audioCodePreference, isEnabled: true),
                ChooseOptionCell(accessType: .chose, title: AudioSettingsOption.audioPacketInterval.rawValue, options: AudioSettingsOption.options.audioPacketInterval, isEnabled: true)
            ]),
            SettingsSection(headerTitle: .forwardErrorCorrection, options: [
                ChooseOptionCell(accessType: .pick, title: AudioSettingsOption.packetLoss.rawValue, options: AudioSettingsOption.options.packetLoss, isEnabled: true),
                ChooseOptionCell(accessType: .pick, title: AudioSettingsOption.bitRateMultiplier.rawValue, options: AudioSettingsOption.options.bitRateMultiplier, isEnabled: true)
            ])
        ]
    }
    
    //MARK: - Manage Video Settings
    private func getVideoOptionsToChoose(forCase option: VideoSettingsOption) -> [OptionToChoose]? {
        switch option {
        case .camera:
            return VideoSettingsOption.options.getCameraOptions(with: cameraConfiguration.localCameraOptions, currentCamera: cameraConfiguration.currentLocalCamera)
        case .resolution:
            return VideoSettingsOption.options.resolution
        case .frameRate:
            return VideoSettingsOption.options.frameRate
        case .responseTime:
            return VideoSettingsOption.options.responseTime
        case .sampleTime:
            return VideoSettingsOption.options.sampleTime
        case .lowBandwidthThreshold:
            return VideoSettingsOption.options.lowBandwidthThreshold
        case .audioStreams:
            return VideoSettingsOption.options.audioStreams
        case .send:
            return VideoSettingsOption.options.send
        case .receive:
            return VideoSettingsOption.options.receive
        default:
            return nil
        }
    }

    private func setNewValuesForVideoIfPossible(_ array: [OptionToChoose], optionIndex: Int, forCase optionType: VideoSettingsOption) -> Bool {
        switch optionType {
        case .camera:
            guard cameraConfiguration.setCamera(optionIndex) else { return false }
            VideoSettingsOption.options.camera = array
            
        case .resolution:
            guard let resolution = array[optionIndex].title.resolution else { return false }
            guard cameraConfiguration.setCameraResolution(width: resolution.width, height: resolution.height) else { return false }
            VideoSettingsOption.options.resolution = array
            
        case .frameRate:
            guard let numberToSet = Int(array[optionIndex].title.digits) else { return false }
            guard cameraConfiguration.setFrameRate(numberToSet) else { return false }
            VideoSettingsOption.options.frameRate = array
            
        case .responseTime:
            guard let numberToSet = UInt32(array[optionIndex].title.digits) else { return false }
            guard cameraConfiguration.setDisableVideoOnLowBandwidthResponseTime(numberToSet) else { return false }
            VideoSettingsOption.options.responseTime = array
            
        case .sampleTime:
            guard let numberToSet = UInt32(array[optionIndex].title.digits) else { return false }
            guard cameraConfiguration.setDisableVideoOnLowBandwidthSampleTime(numberToSet) else { return false }
            VideoSettingsOption.options.sampleTime = array
            
        case .lowBandwidthThreshold:
            guard let numberToSet = UInt32(array[optionIndex].title.digits) else { return false }
            guard cameraConfiguration.setDisableVideoOnLowBandwidthThreshold(numberToSet) else { return false }
            VideoSettingsOption.options.lowBandwidthThreshold = array
            
        case .audioStreams:
            guard let numberToSet = UInt32(array[optionIndex].title.digits) else { return false }
            guard cameraConfiguration.setDisableVideoOnLowBandwidthAudioStreams(numberToSet) else { return false }
            VideoSettingsOption.options.audioStreams = array
            
        case .send:
            guard let bts = array[optionIndex].title.digits.toBtsInUInt32 else { return false }
            guard cameraConfiguration.setMaxSendBitRate(bts) else { return false }
            VideoSettingsOption.options.send = array
            
        case .receive:
            guard let bts = array[optionIndex].title.digits.toBtsInUInt32 else { return false }
            guard cameraConfiguration.setMaxReceiveBitRate(bts) else { return false }
            VideoSettingsOption.options.receive = array
            
        default:
            return false
        }
        return true
    }

    private func updateVideoSettingsData() {
        // Set General section
        let cameraOptions = VideoSettingsOption.options.getCameraOptions(with: cameraConfiguration.localCameraOptions, currentCamera: cameraConfiguration.currentLocalCamera) ?? [OptionToChoose]()
        
        if VideoSettingsOption.options.isSwitchOn(forTitle: VideoSettingsOption.disableVideoOnPoorConnection.rawValue) {
            videoData = [
                SettingsSection(headerTitle: .general, options: [
                    ChooseOptionCell(accessType: .chose, title: VideoSettingsOption.camera.rawValue, options: cameraOptions, isEnabled: cameraConfiguration.isCameraAvailableForSelecting),
                    ChooseOptionCell(accessType: .chose, title: VideoSettingsOption.resolution.rawValue, options: VideoSettingsOption.options.resolution, isEnabled: true),
                    ChooseOptionCell(accessType: .chose, title: VideoSettingsOption.frameRate.rawValue, options: VideoSettingsOption.options.frameRate, isEnabled: true),
                    ChooseOptionCell(accessType: .toggle, title: VideoSettingsOption.disableVideoOnPoorConnection.rawValue, options: VideoSettingsOption.options.disableVideoOnPoorConnection, isEnabled: true),
                    ChooseOptionCell(accessType: .input, title: VideoSettingsOption.responseTime.rawValue, options: VideoSettingsOption.options.responseTime, isEnabled: true),
                    ChooseOptionCell(accessType: .input, title: VideoSettingsOption.sampleTime.rawValue, options: VideoSettingsOption.options.sampleTime, isEnabled: true),
                    ChooseOptionCell(accessType: .input, title: VideoSettingsOption.lowBandwidthThreshold.rawValue, options: VideoSettingsOption.options.lowBandwidthThreshold, isEnabled: true),
                    ChooseOptionCell(accessType: .pick, title: VideoSettingsOption.audioStreams.rawValue, options: VideoSettingsOption.options.audioStreams, isEnabled: true)
                ])
            ]
        } else {
            videoData = [
                SettingsSection(headerTitle: .general, options: [
                    ChooseOptionCell(accessType: .chose, title: VideoSettingsOption.camera.rawValue, options: cameraOptions, isEnabled: cameraConfiguration.isCameraAvailableForSelecting),
                    ChooseOptionCell(accessType: .chose, title: VideoSettingsOption.resolution.rawValue, options: VideoSettingsOption.options.resolution, isEnabled: true),
                    ChooseOptionCell(accessType: .chose, title: VideoSettingsOption.frameRate.rawValue, options: VideoSettingsOption.options.frameRate, isEnabled: true),
                    ChooseOptionCell(accessType: .toggle, title: VideoSettingsOption.disableVideoOnPoorConnection.rawValue, options: VideoSettingsOption.options.disableVideoOnPoorConnection, isEnabled: true)
                ])
            ]
        }
        // Append Max Allowed Bandwidth section
        videoData.append(
            SettingsSection(headerTitle: .maxAllowedBandwidth, options: [
                ChooseOptionCell(accessType: .input, title: VideoSettingsOption.send.rawValue, options: VideoSettingsOption.options.send, isEnabled: true),
                ChooseOptionCell(accessType: .input, title: VideoSettingsOption.receive.rawValue, options: VideoSettingsOption.options.receive, isEnabled: true)
            ])
        )
    }
}
