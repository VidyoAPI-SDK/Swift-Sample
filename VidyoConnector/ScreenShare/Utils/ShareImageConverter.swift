//
//  ShareImageConverter.swift
//  BroadcastExtension
//
//  Created by Marta Korol on 25.07.2021.
//

import UIKit
import ReplayKit

class ShareImageConverter {
    func ciImageFrom(pixelBuffer: CVPixelBuffer, orientationDeviation: CGImagePropertyOrientation) -> CIImage? {
        CIImage(cvImageBuffer: pixelBuffer).oriented(orientationDeviation)
    }
    
    func packetDataFromBuffer(imageBuffer: CVPixelBuffer) -> (Data, [String : AnyObject])? {
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        guard let surface = CVPixelBufferGetIOSurface(imageBuffer) else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
            return nil
        }
        var dataToSend = BroadcastExtensionConstants.frameDataStartMarker
        let usableSurface = surface.takeUnretainedValue()
        let properties = IOSurfaceCopyAllValues(usableSurface) as? [String: AnyObject]
        let surfaceProperties = properties?["CreationProperties"] as! [String : AnyObject]
        let length = IOSurfaceGetAllocSize(usableSurface)
        let dBegin = IOSurfaceGetBaseAddress(usableSurface)
        
        dataToSend.append(Data(bytesNoCopy: dBegin, count: length, deallocator: Data.Deallocator.none))
        CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        dataToSend.append(BroadcastExtensionConstants.frameDataEndMarker)
        
        return (dataToSend, surfaceProperties)
    }
}
