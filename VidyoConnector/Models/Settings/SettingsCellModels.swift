//
//  SettingsCellModels.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 14.06.2021.
//

import Foundation

enum SettingsCellAccessType {
    case chose
    case pick
    case input
    case toggle
    case googleAnalitycs
    case vidyoInsight
}

enum SettingsSwitchCell {
    case autoReconnect
    case disableVideoOnPoorConnection
    case debugInfoVisible
    case labelVisible
    case audioMeterVisible
    case previewMirroringEnable
    case showAudioTiles
    case expandedCameraControl
    case feccIconCustomLayout
    case verticalVideoCentering
}

struct SettingsOptionCell {
    var title: SettingsOption
    var iconName: String
    var isEnabled: Bool
}

struct SettingsSection {
    var headerTitle: SettingsSectionHeaderTitle
    var options: [ChooseOptionCell]
}

struct ChooseOptionCell {
    var accessType: SettingsCellAccessType
    var title: String
    var options: [OptionToChoose]
    var isEnabled: Bool
    
    func getChosenOptionTitle() -> String {
        var title = String()
        options.forEach {
            if $0.isChosen {
                title = $0.title
            }
        }
        return title
    }
}

struct OptionToChoose: Equatable {
    var title: String
    var isChosen: Bool
    
    init(title: String, isChosen: Bool) {
        self.title = title
        self.isChosen = isChosen
    }
    
    init(logLevel: LogLevel, isChosen: Bool = false) {
        self.title = logLevel.rawValue
        self.isChosen = isChosen
    }
}
