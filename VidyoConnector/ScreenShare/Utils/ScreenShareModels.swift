//
//  ScreenShareModels.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 30.07.2021.
//

import Foundation

//MARK: - Protocols
protocol ScreenShareOutputListener: class {
    func onStart(_ stream: ScreenShareOutputProtocol, recommendedFPS: Int)
    func onStop(_ stream: ScreenShareOutputProtocol)
    func onReconfigure(_ stream: ScreenShareOutputProtocol, recommendedFPS: Int)
}

protocol ScreenShareOutputProtocol {
    var listener: ScreenShareOutputListener? { get set }
    var started: Bool { get }
    
    func start() throws
    func stop() throws
    func set(maxConstraints: ScreenShareOutputMaxConstraints)
    func sendBuffer(_ buffer: CVImageBuffer)
    
}

//MARK: - Structs & Classes
struct ScreenShareOutputMaxConstraints: CustomStringConvertible {
    let maxFPS: Int
    let maxSize: CGSize
    
    var description: String {
        "Bounds Constraints: maxFPS:\(maxFPS), maxSize:\(maxSize)"
    }
    
    init(maxFPS: Int, maxSize: CGSize) {
        self.maxFPS = maxFPS
        self.maxSize = maxSize
    }
    
    init(maxFPS: Int) {
        self.maxFPS = maxFPS
        self.maxSize = UIScreen.main.bounds.size
    }
}

struct FrameRateCellModel {
    enum SharingType: String {
        case normal = "Normal Frame Rate"
        case high = "High Frame Rate"
    }
    
    let type: SharingType
    var isSelected: Bool
    var accessoryType: UITableViewCell.AccessoryType {
        isSelected ? .checkmark : .none
    }
    
    init(type: SharingType, isSelected: Bool = false) {
        self.type = type
        self.isSelected = isSelected
    }
}

class ScreenShareOutputFactory: NSObject {
    func createShareOuptut(constraints: ScreenShareOutputMaxConstraints) throws -> ScreenShareOutputProtocol {
        guard let stream = ScreenShareOutput(constraints: constraints) else {
            throw ScreenShareOutputException.missingVirtualVideoSource
        }
        return stream
    }
}

class FrameData {
    let imageOrientation: CGImagePropertyOrientation
    let pixelBuffer: Unmanaged<CVPixelBuffer>
    
    init(imageOrientation: CGImagePropertyOrientation, unmanagedPixelBuffer: Unmanaged<CVPixelBuffer>) {
        self.imageOrientation = imageOrientation
        self.pixelBuffer = unmanagedPixelBuffer
    }
    
    deinit {
        pixelBuffer.release()
    }
}

class UnitsConversion {
    static func secondTimeInterval(fps: Int) -> TimeInterval {
        return 1.0 / Double(fps)
    }
    static func frameInterval(fps: Int) -> Int {
        return 1000000000 / fps
    }
    static func fps(frameInterval: Int) -> Int {
        return 1000000000 / frameInterval
    }
}

//MARK: - Enums
enum ScreenShareOutputException: Error {
    case missingVirtualVideoSource
    case failedToRegisterSourceListener
    case invalidFPS(Int)
    case startingActiveStream
    case stoppingInactiveStream
}

enum ScreenSpace {
    case fullScreen
    case splitView(CGRect)
    case slideOver
    
    var isFullScreen: Bool {
        switch self {
        case .fullScreen: return true
        default: return false
        }
    }
}
