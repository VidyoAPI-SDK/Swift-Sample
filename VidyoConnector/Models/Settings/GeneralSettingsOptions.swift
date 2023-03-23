//
//  GeneralSettingsOptions.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 14.06.2021.
//

import Foundation

enum GeneralSettingsOption: String, CaseIterable {
    case cpuProfile = "CPU Profile"
    case networkSignaling = "Network for Signaling"
    case networkMedia = "Network for Media"
    case participants = "Select Number of Participants"
    case selfView = "Selfview Options"
    
    case enableAutoReconnect = "Auto Reconnect"
    case reconnectAttempts = "Max Reconnect Attempts"
    case reconnectBackTime = "Reconnect Back Off"
    
    case googleAnalitycs = "Google Analytics"
    case vidyoInsight = "Vidyo Insight"
    
    static var options = GeneralSecondaryOptions()
}

struct GeneralSecondaryOptions {
    private let participantsRange = 1...9
    private let reconnectAttemptsRange = 1...4
    private let reconnectBackTimeRange = 2...20
    private let autoReconnectSetting = DefaultValuesManager.shared.getAutoReconnectSetting()
    
    var networkSignaling: [OptionToChoose]?
    var networkMedia: [OptionToChoose]?
    
    var cpuProfile: [OptionToChoose] = {
        var options = [
            OptionToChoose(title: CPUProfileOption.high.rawValue, isChosen: false),
            OptionToChoose(title: CPUProfileOption.medium.rawValue, isChosen: false),
            OptionToChoose(title: CPUProfileOption.low.rawValue, isChosen: false)
        ]
        let cpuProfile = DefaultValuesManager.shared.getCPUProfile()
        options[cpuProfile.rawValue].isChosen = true
        return options
    }()
    
    var selfView = [
        OptionToChoose(title: SelfViewOption.bottomRight.rawValue, isChosen: true)
    ]
    
    var analitycs = [
        OptionToChoose(title: String(), isChosen: true)
    ]
    
    lazy var participants: [OptionToChoose] = {
        var options = createNumericalOptions(forRange: participantsRange)
        options[4].isChosen = true
        return options
    }()
    
    lazy var autoReconnectEnabled: [OptionToChoose] = {
        var options = [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: false),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: true)
        ]
        guard let enableAutoReconnect = autoReconnectSetting?.enableAutoReconnect else { return options }
        options[0].isChosen = enableAutoReconnect
        options[1].isChosen = !enableAutoReconnect
        return options
    }()
    
    lazy var reconnectAttempts: [OptionToChoose] = {
        var options = createNumericalOptions(forRange: reconnectAttemptsRange)
        guard let attempts = autoReconnectSetting?.maxReconnectAttempts else { return options }
        let index = Int(attempts) - 1
        guard index < options.count else { return options }
        options[index].isChosen = true
        return options
    }()
    
    lazy var reconnectBackTime: [OptionToChoose] = {
        var options = [OptionToChoose]()
        reconnectBackTimeRange.forEach {
            options.append(OptionToChoose(title: "\($0) sec", isChosen: false))
        }
        guard let backoff = autoReconnectSetting?.reconnectBackoff else { return options }
        let index = Int(backoff) - 2
        guard index < options.count else { return options }
        options[index].isChosen = true
        return options
    }()
    
    // MARK: - Functions
    private func createNumericalOptions(forRange range: ClosedRange<Int>) -> [OptionToChoose] {
        var options = [OptionToChoose]()
        range.forEach {
            options.append(OptionToChoose(title: String($0), isChosen: false))
        }
        return options
    }
    
    mutating func getNetworkSignaling(with networksSignaling: SynchronizedArray<VCNetworkInterface>, _ currentNetwork: VCNetworkInterface?) -> [OptionToChoose]? {
        guard networkSignaling == nil else { return networkSignaling }
        var options = [OptionToChoose]()
        networksSignaling.forEach {
            if $0 == currentNetwork {
                options.append(OptionToChoose(title: "\($0.getName()!) - \($0.getAddress()!)", isChosen: true))
            } else {
            options.append(OptionToChoose(title: "\($0.getName()!) - \($0.getAddress()!)", isChosen: false))
            }
        }
        networkSignaling = options
        return networkSignaling
    }
    
    mutating func getNetworkMedia(with networksMedia: SynchronizedArray<VCNetworkInterface>, _ currentNetwork: VCNetworkInterface?) -> [OptionToChoose]? {
        guard networkMedia == nil else { return networkMedia }
        var options = [OptionToChoose]()
        networksMedia.forEach {
            if $0 == currentNetwork {
                options.append(OptionToChoose(title: "\($0.getName()!) - \($0.getAddress()!)", isChosen: true))
            } else {
            options.append(OptionToChoose(title: "\($0.getName()!) - \($0.getAddress()!)", isChosen: false))
            }
        }
        networkMedia = options
        return networkMedia
    }
    
    mutating func switchToggle(forTitle title: SettingsSwitchCell, withValue isOn: Bool) {
        let changedData = [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: isOn),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !isOn)
        ]
        
        switch title {
        case .autoReconnect:
            autoReconnectEnabled = changedData
        default: return
        }
    }
    
    mutating func isSwitchOn(forTitle title: String) -> Bool {
        let switchType = GeneralSettingsOption(rawValue: title)
        switch switchType {
        case .enableAutoReconnect:
            return autoReconnectEnabled[0].isChosen
        default: return false
        }
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
