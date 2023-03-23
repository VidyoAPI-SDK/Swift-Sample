//
//  BroadcastExtensionConstants.swift
//  BroadcastExtension
//
//  Created by Marta Korol on 25.07.2021.
//

import UIKit

struct BroadcastExtensionConstants {
    
    static let extensionFinishDelay: TimeInterval = 0.5
    
    static let bundleId = "io.vidyo.Connector"
    static let applicationGroupIdentifier = "group.broadcast.screensharing"
    static let broascastExtensionBundleId = "io.vidyo.Connector.BroadcastExtension"
    
    static let isBroadcastStarted = "isBroadcastStarted"
    static let ioSurfacePropertiesDefaultsKey = "IOSurfacePropertyKey"
    static let orientationDefaultsKey = "orientationDefaultsKey"
    static let frameDataLengthKey = "dataLength"
    static let broadcastExtensionLogsDirectoryName = "BroadcastExtensionLogs"
    static let frameDataStartMarker: Data = "frameDataStartMarker".data(using: .utf8)!
    static let frameDataEndMarker: Data = "frameDataEndMarker".data(using: .utf8)!
    
    struct CFNotificationNames {
        static let broadcastStarted = "io.vidyo.Connector.broadcastStarted"
        static let broadcastPaused = "io.vidyo.Connector.broadcastPaused"
        static let broadcastResumed = "io.vidyo.Connector.broadcastResumed"
        static let broadcastFinished = "io.vidyo.Connector.broadcastFinished"
        static let newFrameAvailable = "io.vidyo.Connector.newFrameAvailable"
        
        static let callEnded = "io.vidyo.Connector.callEnded"
        static let shareOverriden = "io.vidyo.Connector.shareOverriden"
        static let shareOverrideForbidden = "io.vidyo.Connector.shareOverrideForbidden"
        static let shareIsDisabled = "io.vidyo.Connector.shareIsDisabled"
        static let unknownError = "io.vidyo.Connector.unknownError"
    }
    
    struct Screenshare {
        static let startScreenShareTitle = "Start screen share"
        static let stopScreenShareTitle = "Stop screen share"
        static let frameRateDescription = "Normal Frame Rate is recommended for sharing static documents, presentations, images etc.\n\nHigh Frame Rate is recommended for sharing videos."
        static let startScreenShareMessage = "Tap the recording button below or in your Control Center to start sharing your device screen"
        static let stopScreenShareMessage = "Tap the recording button below or in your Control Center to stop sharing your device screen"
        
        static let noActiveConferenceError = "No active conference."
        static let systemError = "A system error occurred. Please restart your device."
    }
}
