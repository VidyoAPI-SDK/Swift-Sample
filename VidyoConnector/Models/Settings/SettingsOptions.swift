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
    case logs = "Logs"
    case renderer = "Renderer"
    case about = "About"
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
    //Renderer
    case conference = "Conference"
}

// General Settings
enum CPUProfileOption: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

enum SelfViewOption: String {
    case topRight = "Top Right"
    case topLeft = "Top Left"
    case bottomRight = "Bottom Right"
    case bottomLeft = "Bottom Left"
    case centerRight = "Center Right"
    case centerLeft = "Center Left"
    case topCenter = "Top Center"
    case centerCenter = "Center Center"
    case bottomCenter = "Bottom Center"
}

enum BorderStyleOption: String {
    case highlight = "Highlight"
    case flash = "Flash"
    case same = "Same"
    case none = "None"
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
