//
//  SettingsOptions.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 17.06.2021.
//

import Foundation

enum SettingsOption: String {
    case general = "General"
    case audio = "Audio"
    case video = "Video"
    case account = "Account"
    case logs = "Logs"
    case about = "About"
    case help = "Help"
}

enum SettingsSectionHeaderTitle: String {
    case general = "General"
    //General
    case autoRecconect = "Auto Reconnect"
    case googleAnalytics = "Google Analytics"
    case vidyoInsight = "Vidyo Insight"
    //Audio
    case deviceSelection = "Device selection"
    case forwardErrorCorrection = "Forward Error Correction (FEC)"
    //Video
    case maxAllowedBandwidth = "Max Allowed Bandwidth"
}

// General Settings
enum CPUProfileOption: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

enum SelfViewOption: String {
    case bottomRight = "Bottom Right"
}

// Audio Settings
enum AudioCodePreference: String {
    case opus = "OPUS"
    case speexRed = "SPEEX RED"
}

// Logs
enum LogLevel: String {
    case debug = "Debug"
    case production = "Production"
    case advanced = "Advanced"
}

enum SwitchOption: String {
    case isOn
    case isOff
}
