//
//  CameraBackground.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 01.09.2021.
//

import Foundation

enum BackgroundType: String {
    case none = "None"
    case photo = "Use Your Image"
    case blur = "Blur Background"
    case image = ""
}

struct BackgroundModel {
    var type: BackgroundType
    var title: String
    var image: UIImage?
    var path: String?
    var isSelected: Bool
    
    init(type: BackgroundType, image: UIImage? = nil, path: String? = nil, title: String? = nil, isSelected: Bool = false) {
        self.type = type
        self.title = title ?? type.rawValue
        self.image = image
        self.path = path
        self.isSelected = isSelected
    }
}

struct BackgroundResoursesConstants {
    // String
    static private let bundlePath = Bundle.main.resourcePath ?? ""
    static private let pathToResourcesString = String(format: "%@/Frameworks/BNBEffectPlayerC.framework/bnb-resources", bundlePath)
    static private let blurPathToEffectString = String(format: "%@/effects/blurred-background", bundlePath)
    static private let virtualBackgroundPathString = String(format: "%@/effects/virtual-background", bundlePath)
    
    static let imagePathFormat = "\(bundlePath)/BackgroundImages/%@.jpg"
    
    // NSMutableString
    static let token = NSMutableString(utf8String: BANUBA_GITHUB_TOKEN)
    static let pathToResources = NSMutableString(utf8String: pathToResourcesString)
    static let blurPathToEffect = NSMutableString(utf8String: blurPathToEffectString)
    static let virtualBackgroundPath = NSMutableString(utf8String: virtualBackgroundPathString)
}
