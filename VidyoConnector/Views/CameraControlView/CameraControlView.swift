//
//  CameraControlView.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 03.08.2021.
//

import UIKit

class CameraControlView: UIView {
    enum ControlAction: Int {
        case moveUp
        case moveRight
        case moveDown
        case moveLeft
        case zoomOut
        case zoomIn
    } // don't change the case order, rawValue matches the button tag
    
    // MARK: - IBOutlets
    @IBOutlet weak var participantName: UILabel!
    @IBOutlet weak var nameView: UIView!
    @IBOutlet weak var circleView: UIView!
    @IBOutlet weak var zoomView: UIView!
    
    // MARK: - Const & vars
    var remoteCameraInfo: RemoteControllableCamera?
    var remoteCameraManager: RemoteCameraManager?
    var onCloseButtonPressed: (() -> ())?
        
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        
        circleView.layer.cornerRadius = 70
        zoomView.layer.cornerRadius = 20
        
        circleView.layer.borderWidth = 1
        circleView.layer.borderColor = UIColor.lightGray.cgColor
        
        zoomView.layer.borderWidth = 1
        zoomView.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    // MARK: - IBActions
    @IBAction func closeButtonPressed(_ sender: UIButton) {
        onCloseButtonPressed?()
    }
    
    @IBAction func touchStarted(_ sender: UIButton) {
        startControl(forTag: sender.tag)
    }
    
    @IBAction func touchFinished(_ sender: UIButton) {
        stopControl()
    }
    
    // MARK: - Methods
    func prepareToControl(with camera: RemoteControllableCamera, manager: RemoteCameraManager) {
        participantName.text = camera.partisipantName
        remoteCameraManager = manager
    }
    
    func startControl(forTag tag: Int) {
        guard let remoteCameraManager = remoteCameraManager else {
            log.info("No RemoteCameraManager object found. Cannot start camera control.")
            return
        }
        switch tag {
        case ControlAction.moveUp.rawValue: remoteCameraManager.startControl(.tiltUp)
        case ControlAction.moveRight.rawValue: remoteCameraManager.startControl(.panRight)
        case ControlAction.moveDown.rawValue: remoteCameraManager.startControl(.tiltDown)
        case ControlAction.moveLeft.rawValue: remoteCameraManager.startControl(.panLeft)
        case ControlAction.zoomOut.rawValue: remoteCameraManager.startControl(.zoomOut)
        case ControlAction.zoomIn.rawValue: remoteCameraManager.startControl(.zoomIn)
        default: return
        }
    }
    
    func stopControl() {
        guard let remoteCameraManager = remoteCameraManager else {
            log.info("No RemoteCameraManager object found. Cannot stop camera control.")
            return
        }
        remoteCameraManager.stopControl()
    }
}
