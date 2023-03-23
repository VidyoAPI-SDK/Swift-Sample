//
//  Constants.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 31.05.2021.
//

import Foundation

struct Constants {
    static let defaultHeightForRow: CGFloat = 60
    
    struct Icon {
        static let settings = "settings"
        
        static let cameraOn = "cameraOn"
        static let cameraMuted = "cameraMuted"
        static let cameraDisabled = "cameraDisabled"
        
        static let micOn = "micOn"
        static let micMuted = "micMuted"
        static let micDisabled = "micDisabled"
        
        static let speakerOn = "speakerOn"
        static let speakerMuted = "speakerMuted"
        static let speakerDisabled = "speakerDisabled"
        
        static let background = "background"
        static let backgroundActive = "backgroundActive"
        static let backgroundDisabled = "backgroundDisabled"
        
        static let more = "more"
        static let moreDisabled = "moreDisabled"
        
        static let chat = "chat"
        
        static let endCall = "endCall"
        
        static let localCamera = "localCamera"
        static let localCameraActive = "localCameraActive"
        
        static let moderator = "moderator"
        static let moderatorActive = "moderatorActive"
        
        static let multipleShare = "multipleShare"
        static let multipleShareActive = "multipleShareActive"
        
        static let participants = "participants"
        
        static let raiseHand = "raiseHand"
        static let unraiseHand = "unraiseHand"
        
        static let share = "share"
        static let shareActive = "shareActive"
        
        static let fecc = "fecc"
        static let feccActive = "feccActive"
        
        // Settings
        static let account = "account"
        static let accountDisabled = "accountDisabled"
        
        static let audio = "audio"
        static let audioDisabled = "audioDisabled"
        
        static let general = "general"
        static let generalDisabled = "generalDisabled"
        
        static let help = "help"
        static let helpDisabled = "helpDisabled"
        
        static let info = "info"
        static let infoDisabled = "infoDisabled"
        
        static let logs = "logs"
        static let logsDisabled = "logsDisabled"
        
        static let video = "video"
        static let videoDisabled = "videoDisabled"
        
        static let voiceProcessing = "voiceProcessing"
        static let voiceProcessingDisabled = "voiceProcessingDisabled"
        
        static let sendBubble = "sendBubble"
        static let receiveBubble = "receiveBubble"
        
        static let none = "none"
        static let blur = "blur"
    }
    
    enum IconBG: String, CaseIterable {
        case virtual_bg_1 = "virtual_bg_1"
        case virtual_bg_2 = "virtual_bg_2"
        case virtual_bg_3 = "virtual_bg_3"
        case virtual_bg_4 = "virtual_bg_4"
        case virtual_bg_5 = "virtual_bg_5"
        case virtual_bg_6 = "virtual_bg_6"
        case virtual_bg_7 = "virtual_bg_7"
    }
    
    struct SystemImage {
        static let back = "chevron.backward"
    }
    
    struct Color {
        static let settingsHeaderBackground = UIColor(red: 241/256, green: 242/256, blue: 244/256, alpha: 1.0)
        static let analyticsTextFieldBorder = CGColor(red: 105/256, green: 105/256, blue: 105/256, alpha: 1)
        static let customLightGreen = UIColor(named: "GreenAccentColor")
    }
    
    struct LogsFile {
        static let name = "Logs"
        static var pathUrl: URL {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        static var pathString: String {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path
        }
    }
    
    struct TableViewCellID {
        static let optionCell = "OptionCell"
        static let googleAnalyticsCell = "GoogleAnalyticsOptionCell"
    }
    
    struct ParticipantsScreen {
        static let title = "Participants (%@)"
        static let heightForTableViewRow: CGFloat = 56
    }
    
    struct Chat {
        static let groupChatImage = UIImage(named: "chat")
        static let textFieldPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 5, height: 0))
        static let partisipantLeftMessage = "%@ left the conference. \nYou are not able to send messages."
    }
    
    struct ModerationResponse {
        static let approved = "Moderator approved your raised hand.\nPlease unmute yourself to speak."
        static let dismissed = "Moderator declined your raised hand."
    }
    
    struct SettingsTableView {
        static let heightForHeader: CGFloat = 50
        static let heightForAnalyticsRow: CGFloat = 65
    }
    
    struct SettingsPickerView {
        static let height: CGFloat = UIScreen.main.bounds.height/2
        static let rowHeightForComponent: CGFloat = 55
        static let numberOfComponents = 1
    }
    
    struct DefaultCameraConstraint {
        static let width: UInt32 = 640
        static let height: UInt32 = 480
        static let frameRate: Int = 30
    }
    
    struct ConferenceToolbar {
        static let mainHeight: CGFloat = 48
        static let fullHeight: CGFloat = 96
        static let heightConstraintId = "ToolbarHeight"
    }
}

struct UserInfoKey {
    static let participant = "participant"
    static let groupMessage = "groupMessage"
    static let privateChat = "privateChat"
    static let notification = "notification"
}
