//
//  AnalyticsEvent.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.06.2021.
//

import Foundation
import VidyoClientIOS

struct GoogleAnalyticsEvent: Equatable {
    var title: AnalyticsEventCategory
    var eventCategory: VCConnectorGoogleAnalyticsEventCategory
    var subtitle: AnalyticsEventAction
    var eventAction: VCConnectorGoogleAnalyticsEventAction
    var isEnabled: Bool = true
    
    mutating func changeEnabledStatus() {
        isEnabled = !isEnabled
    }
}

enum AnalyticsEventCategory: String {
    case login = "Login"
    case userType = "User type"
    case joinConference = "Join Conference"
    case conferenceEnd = "Conference End"
    case inCallCodec = "In Call Codec"
}

enum AnalyticsEventAction: String {
    // Login
    case loginAttempt = "Attempt"
    case loginSuccess = "Success"
    case loginFailedAuthentication = "Failed: Authentication failed"
    case loginFailedConnect = "Failed: Failed to connect"
    case loginFailedResponseTimeout = "Failed: Response timeout"
    case loginFailedMiscError = "Failed: Misc error"
    case loginFailedWebProxyAuthRequired = "Failed: WebProxy authentication required"
    case loginFailedUnsupportedTenantVersion = "Failed: Unsupported tenant version"
    
    // User type
    case userTypeGuest = "Guest"
    case userTypeRegularToken = "Regular: Token"
    case userTypeRegularPassword = "Regular: Password"
    case userTypeRegularSaml = "Regular: Saml"
    case userTypeRegularExtdata = "Regular: Extdata"
    
    //Join conference
    case joinConferenceAttempt = "Join Attempt"
    case joinConferenceSuccess = "Join Success"
    case joinConferenceReconnectRequests = "Reconnect Requests"
    case joinConferenceFailedConnectionError = "Failed: Connection error"
    case joinConferenceFailedWrongPin = "Failed: Wrong pin"
    case joinConferenceFailedRoomFull = "Failed: Room full"
    case joinConferenceFailedRoomDisabled = "Failed: Room disabled"
    case joinConferenceFailedConferenceLocked = "Failed: Conference locked"
    case joinConferenceFailedUnknownError = "Failed: Unknown error"
    
    //Conference end
    case conferenceEndBooted = "Left"
    case conferenceEndLeft = "Booted"
    case conferenceEndSignalingConnectionLost = "Signaling Connection lost"
    case conferenceEndMediaConnectionLost = "Media Connection lost"
    case conferenceEndUnknownError = "Unknown error"
    
    //In Call codec
    case inCallCodecVideoH264 = "Video H264"
    case inCallCodecVideoH264SVC = "Video H264-SVC"
    case inCallCodecAudioSPEEXRED = "Audio SPEEX-RED"
}

struct AnalyticsEventTable {
    static var eventaTable = [
        // Login
        GoogleAnalyticsEvent(title: .login, eventCategory: .login, subtitle: .loginAttempt, eventAction: .loginAttempt),
        GoogleAnalyticsEvent(title: .login, eventCategory: .login, subtitle: .loginSuccess, eventAction: .loginSuccess),
        GoogleAnalyticsEvent(title: .login, eventCategory: .login, subtitle: .loginFailedAuthentication, eventAction: .loginFailedAuthentication),
        GoogleAnalyticsEvent(title: .login, eventCategory: .login, subtitle: .loginFailedConnect, eventAction: .loginFailedConnect),
        GoogleAnalyticsEvent(title: .login, eventCategory: .login, subtitle: .loginFailedResponseTimeout, eventAction: .loginFailedResponseTimeout),
        GoogleAnalyticsEvent(title: .login, eventCategory: .login, subtitle: .loginFailedMiscError, eventAction: .loginFailedMiscError),
        GoogleAnalyticsEvent(title: .login, eventCategory: .login, subtitle: .loginFailedWebProxyAuthRequired, eventAction: .loginFailedWebProxyAuthRequired),
        GoogleAnalyticsEvent(title: .login, eventCategory: .login, subtitle: .loginFailedUnsupportedTenantVersion, eventAction: .loginFailedUnsupportedTenantVersion),
        
        // User type
        GoogleAnalyticsEvent(title: .userType, eventCategory: .userType, subtitle: .userTypeGuest, eventAction: .userTypeGuest),
        GoogleAnalyticsEvent(title: .userType, eventCategory: .userType, subtitle: .userTypeRegularToken, eventAction: .userTypeRegularToken),
        GoogleAnalyticsEvent(title: .userType, eventCategory: .userType, subtitle: .userTypeRegularPassword, eventAction: .userTypeRegularPassword),
        GoogleAnalyticsEvent(title: .userType, eventCategory: .userType, subtitle: .userTypeRegularSaml, eventAction: .userTypeRegularSaml),
        GoogleAnalyticsEvent(title: .userType, eventCategory: .userType, subtitle: .userTypeRegularExtdata, eventAction: .userTypeRegularExtdata),
        
        //Join conference
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceAttempt, eventAction: .joinConferenceAttempt),
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceSuccess, eventAction: .joinConferenceSuccess),
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceReconnectRequests, eventAction: .joinConferenceReconnectRequests),
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceFailedConnectionError, eventAction: .joinConferenceFailedConnectionError),
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceFailedWrongPin, eventAction: .joinConferenceFailedWrongPin),
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceFailedRoomFull, eventAction: .joinConferenceFailedRoomFull),
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceFailedRoomDisabled, eventAction: .joinConferenceFailedRoomDisabled),
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceFailedConferenceLocked, eventAction: .joinConferenceFailedConferenceLocked),
        GoogleAnalyticsEvent(title: .joinConference, eventCategory: .joinConference, subtitle: .joinConferenceFailedUnknownError, eventAction: .joinConferenceFailedUnknownError),
        
        //Conference end
        GoogleAnalyticsEvent(title: .conferenceEnd, eventCategory: .conferenceEnd, subtitle: .conferenceEndBooted, eventAction: .conferenceEndBooted),
        GoogleAnalyticsEvent(title: .conferenceEnd, eventCategory: .conferenceEnd, subtitle: .conferenceEndLeft, eventAction: .conferenceEndLeft),
        GoogleAnalyticsEvent(title: .conferenceEnd, eventCategory: .conferenceEnd, subtitle: .conferenceEndSignalingConnectionLost, eventAction: .conferenceEndSignalingConnectionLost),
        GoogleAnalyticsEvent(title: .conferenceEnd, eventCategory: .conferenceEnd, subtitle: .conferenceEndMediaConnectionLost, eventAction: .conferenceEndMediaConnectionLost),
        GoogleAnalyticsEvent(title: .conferenceEnd, eventCategory: .conferenceEnd, subtitle: .conferenceEndUnknownError, eventAction: .conferenceEndUnknownError),
        
        //In Call codec
        GoogleAnalyticsEvent(title: .inCallCodec, eventCategory: .inCallCodec, subtitle: .inCallCodecVideoH264, eventAction: .inCallCodecVideoH264),
        GoogleAnalyticsEvent(title: .inCallCodec, eventCategory: .inCallCodec, subtitle: .inCallCodecVideoH264SVC, eventAction: .inCallCodecVideoH264SVC),
        GoogleAnalyticsEvent(title: .inCallCodec, eventCategory: .inCallCodec, subtitle: .inCallCodecAudioSPEEXRED, eventAction: .inCallCodecAudioSPEEXRED)
    ]
}
