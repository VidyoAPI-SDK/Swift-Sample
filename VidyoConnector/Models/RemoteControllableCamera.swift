//
//  RemoteControllableCamera.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 10.08.2021.
//

import Foundation
import VidyoClientIOS

struct RemoteControllableCamera: Equatable {
    let id: String
    let participantName: String
    let remoteCamera: VCRemoteCamera
    let controlCapabilities: VCCameraControlCapabilities
    
    var isOnlyNudgeSupportsForMove: Bool {
        controlCapabilities.panTiltHasNudge &&
            !controlCapabilities.panTiltHasRubberBand  &&
                !controlCapabilities.panTiltHasContinuousMove
    }
    
    var isOnlyNudgeSupportsForZoom: Bool {
        controlCapabilities.zoomHasNudge &&
            !controlCapabilities.zoomHasRubberBand &&
                !controlCapabilities.zooomHasContinuousMove
    }
    
    init(id: String, participantName: String, remoteCamera: VCRemoteCamera, controlCapabilities: VCCameraControlCapabilities) {
        self.id = id
        self.remoteCamera = remoteCamera
        self.participantName = participantName
        self.controlCapabilities = controlCapabilities
    }
}
