//
//  CMSampleBuffer+Orientation.swift
//  BroadcastExtension
//
//  Created by Marta Korol on 20.07.2021.
//

import Foundation
import ReplayKit

extension CMSampleBuffer {
    func replayKitFrameOrientationDeviation() -> CGImagePropertyOrientation? {
        guard let orientNum = CMGetAttachment(self, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber else {
            return nil
        }        
        guard let  orientationDeviation = CGImagePropertyOrientation(rawValue: orientNum.uint32Value) else {
            return nil
        }
        switch orientationDeviation {
        case .left:
            return .right
        case .right:
            return .left
        default:
            return orientationDeviation
        }
    }
}
