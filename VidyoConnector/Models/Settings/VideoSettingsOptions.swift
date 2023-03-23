//
//  VideoSettingsOptions.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 23.06.2021.
//

import Foundation

enum VideoSettingsSectionHeaderTitle: String {
    case general = "General"
    case maxAllowedBandwidth = "Max Allowed Bandwidth"
}

enum VideoSettingsOption: String, CaseIterable {
    case camera = "Camera"
    case resolution = "Resolution"
    case frameRate = "Frame Rate"
    
    case disableVideoOnPoorConnection = "Disable Video on Poor Connection"
    case responseTime = "Response Time"
    case sampleTime = "Sample Time"
    case lowBandwidthThreshold = "Low Bandwidth Threshold"
    case audioStreams = "Audio Streams"
    
    case send = "Send"
    case receive = "Receive"
    
    static var options = VideoSecondaryOptions()
}

struct VideoSecondaryOptions {
    private let responseTimeDefaultValue: UInt32 = 30
    private let sampleTimeDefaultValue: UInt32 = 5
    private let thresholdDefaultValue: UInt32 = 150
    private let audioStreamsRange = 1...3
    
    private var maxSendBitRateDefaultValue: UInt32 {
        return DefaultValuesManager.shared.getMaxSendBitRateBps() / 1_000_000
    }
    private var maxReceiveBitRateDefaultValue: UInt32 {
        return DefaultValuesManager.shared.getMaxReceiveBitRateBps() / 1_000_000
    }
    
    var camera: [OptionToChoose]?
    
    var resolution = [
        OptionToChoose(title: "320 x 240", isChosen: false),
        OptionToChoose(title: "352 x 288", isChosen: false),
        OptionToChoose(title: "640 x 480", isChosen: true),
        OptionToChoose(title: "960 x 540", isChosen: false),
        OptionToChoose(title: "1280 x 720", isChosen: false),
        OptionToChoose(title: "1920 x 1080", isChosen: false),
        OptionToChoose(title: "3840 x 2160", isChosen: false)
    ]
    
    var frameRate = [
        OptionToChoose(title: "7 fps", isChosen: false),
        OptionToChoose(title: "15 fps", isChosen: false),
        OptionToChoose(title: "30 fps", isChosen: true),
        OptionToChoose(title: "60 fps", isChosen: false)
    ]

    var disableVideoOnPoorConnection = [
        OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: false),
        OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: true)
    ]
    
    lazy var responseTime = [
        OptionToChoose(title: "\(responseTimeDefaultValue) sec", isChosen: true)
    ]
    
    lazy var sampleTime = [
        OptionToChoose(title: "\(sampleTimeDefaultValue) sec", isChosen: true)
    ]
    
    lazy var lowBandwidthThreshold = [
        OptionToChoose(title: "\(thresholdDefaultValue) kBps", isChosen: true)
    ]
    
    lazy var audioStreams: [OptionToChoose] = {
        var options = createNumericalOptions(forRange: audioStreamsRange)
        options[0].isChosen = true
        return options
    }()
    
    lazy var send = [
        OptionToChoose(title: "\(maxSendBitRateDefaultValue) MBps", isChosen: true)
    ]
    
    lazy var receive = [
        OptionToChoose(title: "\(maxReceiveBitRateDefaultValue) MBps", isChosen: true)
    ]
    
    mutating func getCameraOptions(with localCameras: SynchronizedArray<VCLocalCamera>, currentCamera: VCLocalCamera?) -> [OptionToChoose]? {
        guard camera == nil else { return camera }
        
        var options = [OptionToChoose]()
        localCameras.forEach { localCamera in
            if localCamera == currentCamera {
                options.append(OptionToChoose(title: localCamera.name as String, isChosen: true))
            } else {
                options.append(OptionToChoose(title: localCamera.name as String, isChosen: false))
            }
        }
        camera = options
        return camera
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
    
    func getDefaultValue(forOption option: VideoSettingsOption) -> UInt32? {
        switch option {
        case .responseTime:
            return responseTimeDefaultValue
        case .sampleTime:
            return sampleTimeDefaultValue
        case .lowBandwidthThreshold:
            return thresholdDefaultValue
        case .send:
            return maxSendBitRateDefaultValue
        case .receive:
            return maxReceiveBitRateDefaultValue
        default: return nil
        }
    }
    
    func isSwitchOn(forTitle title: String) -> Bool {
        let switchType = VideoSettingsOption(rawValue: title)
        if switchType == .disableVideoOnPoorConnection {
            return disableVideoOnPoorConnection[0].isChosen
        }
        return false
    }
    
    mutating func switchToggle(forTitle title: SettingsSwitchCell, withValue isOn: Bool) {
        let changedData = [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: isOn),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !isOn)
        ]
        
        switch title {
        case .disableVideoOnPoorConnection:
            disableVideoOnPoorConnection = changedData
        default: return
        }
    }
    
    private func createNumericalOptions(forRange range: ClosedRange<Int>) -> [OptionToChoose] {
        var options = [OptionToChoose]()
        range.forEach {
            options.append(OptionToChoose(title: String($0), isChosen: false))
        }
        return options
    }
}
