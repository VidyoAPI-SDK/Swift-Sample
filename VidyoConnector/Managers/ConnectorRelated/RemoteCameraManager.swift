//
//  RemoteCameraManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 05.07.2021.
//

import Foundation
import VidyoClientIOS

class RemoteCameraManager {
    let connector = ConnectorManager.shared.connector
    
    private let defaultTimeout = 330
    private let timerIntrval = 0.1 // 100 ms
    private var timer = Timer()
    private var shouldStopControl: Bool = false
    private var cameraToControl: VCRemoteCamera?
    private var remoteControllableCamera: RemoteControllableCamera?
    
    var remoteControllableCameras = SynchronizedArray<RemoteControllableCamera>()
    
    var onRemoteCameraAddedHandler: ((VCParticipant) -> ())?
    var onRemoteCameraStateUpdatedHandler: ((VCParticipant, Bool) -> ())?
    var onRemoteCameraRemovedHandler: ((VCParticipant) -> ())?
    
    func registerRemoteCameraEventListener() {
        connector.registerRemoteCameraEventListener(self)
    }
    
    func unregisterRemoteCameraEventListener() {
        connector.unregisterRemoteCameraEventListener()
    }
    
    func selectCameraToControl(_ object: RemoteControllableCamera) {
        remoteControllableCamera = object
        cameraToControl = object.remoteCamera
    }
      
    func startControl(_ direction: VCCameraControlDirection) {
        guard let cameraInfo = remoteControllableCamera else { return }
        
        if direction == .zoomIn || direction == .zoomOut {
            callAppropriateAPI(for: direction, onlyNudgeSupports: cameraInfo.isOnlyNudgeSupportsForZoom)
        } else {
            callAppropriateAPI(for: direction, onlyNudgeSupports: cameraInfo.isOnlyNudgeSupportsForMove)
        }
    }
    
    func stopControl() {
        timer.invalidate()
        guard shouldStopControl, let camera = cameraToControl else { return }
        shouldStopControl = !camera.controlPTZStop()
    }
    
    private func callAppropriateAPI(for direction: VCCameraControlDirection, onlyNudgeSupports: Bool) {
        if onlyNudgeSupports {
            nudge(direction)
        } else {
            control(direction)
        }
    }
    
    private func control(_ direction: VCCameraControlDirection) {
        guard let camera = cameraToControl else { return }
        shouldStopControl = camera.controlPTZStart(direction, timeout: defaultTimeout)
        timer = Timer.scheduledTimer(withTimeInterval: timerIntrval, repeats: true) { _ in
            camera.controlPTZStart(direction, timeout: self.defaultTimeout)
        }
    }
    
    private func nudge(_ direction: VCCameraControlDirection) {
        guard let camera = cameraToControl else { return }
        switch direction {
        case .panRight: camera.controlPTZNudge(1, tilt: 0, zoom: 0)
        case .panLeft: camera.controlPTZNudge(-1, tilt: 0, zoom: 0)
        case .tiltUp: camera.controlPTZNudge(0, tilt: 1, zoom: 0)
        case .tiltDown: camera.controlPTZNudge(0, tilt: -1, zoom: 0)
        case .zoomIn: camera.controlPTZNudge(0, tilt: 0, zoom: 1)
        case .zoomOut: camera.controlPTZNudge(0, tilt: 0, zoom: -1)
        default: return
        }
    }
    
    private func appendControllableCamera(_ camera: VCRemoteCamera, participant: VCParticipant) {
        guard camera.isControllable() else { return }
        
        let addedCamera = remoteControllableCameras.first(where: {$0.remoteCamera == camera})
        guard addedCamera == nil else { return }
        
        guard let controlCapabilities = camera.getControlCapabilities() else {
            log.error("Cannot get remote camera control capabilities.")
            return
        }
        
        let cameraToControl = RemoteControllableCamera(
            id: participant.getId(),
            partisipantName: participant.getName(),
            remoteCamera: camera,
            controlCapabilities: controlCapabilities
        )
        remoteControllableCameras.append(cameraToControl)
        postRemoteCamerasState()
    }
    
    private func removeControllableCamera(_ camera: VCRemoteCamera) {
        guard let index = remoteControllableCameras.firstIndex(where: {$0.remoteCamera == camera}) else { return }
        remoteControllableCameras.remove(at: index)
        postRemoteCamerasState()
    }
    
    private func postRemoteCamerasState() {
        DispatchQueue.global(qos: .userInteractive).async {
            if self.remoteControllableCameras.isEmpty {
                NotificationCenter.default.post(name: .noRemoteCameraToControl, object: nil)
            } else {
                NotificationCenter.default.post(name: .remoteCameraControlAvailable, object: nil)
            }
        }
    }
}

//MARK: - VCConnectorIRegisterRemoteCameraEventListener
extension RemoteCameraManager: VCConnectorIRegisterRemoteCameraEventListener {
    func onRemoteCameraAdded(_ remoteCamera: VCRemoteCamera!, participant: VCParticipant!) {
        onRemoteCameraAddedHandler?(participant)
    }
    
    func onRemoteCameraRemoved(_ remoteCamera: VCRemoteCamera!, participant: VCParticipant!) {
        onRemoteCameraRemovedHandler?(participant)
        removeControllableCamera(remoteCamera)
    }
    
    func onRemoteCameraStateUpdated(_ remoteCamera: VCRemoteCamera!, participant: VCParticipant!, state: VCDeviceState) {
        onRemoteCameraStateUpdatedHandler?(participant, remoteCamera.isControllable())
        appendControllableCamera(remoteCamera, participant: participant)
    }
}
