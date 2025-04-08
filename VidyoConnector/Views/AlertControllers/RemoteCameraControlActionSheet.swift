//
//  RemoteCameraControlActionSheet.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 05.08.2021.
//

import Foundation

class RemoteCameraControlActionSheet {
    let remoteCameraManager: RemoteCameraManager
    let destination: UIViewController
    let alertSheet: UIAlertController
    
    var onActionSelectedHandler: ((RemoteControllableCamera) -> ())?
    
    init(shareManager: RemoteCameraManager, destination: UIViewController) {
        self.remoteCameraManager = shareManager
        self.destination = destination
        alertSheet = UIAlertController(
            title: "Remote Camera Control",
            message: nil,
            preferredStyle: .actionSheet
        )
        addActions()
    }
    
    func present(from view: UIView) {
        if let popoverController = alertSheet.popoverPresentationController {
          popoverController.sourceView = view
        }
        destination.present(alertSheet, animated: true, completion: nil)
    }
    
    private func addActions() {
        var possibleShareActions = [UIAlertAction]()
           
        // Create actions
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.alertSheet.dismiss(animated: true, completion: nil)
        }
        remoteCameraManager.remoteControllableCameras.forEach { info in
            let action = UIAlertAction(title: "\(info.participantName)", style: .default) { _ in
                self.remoteCameraManager.selectCameraToControl(info)
                self.onActionSelectedHandler?(info)
            }
            possibleShareActions.append(action)
        }
        
        //Add actions to alert controller
        possibleShareActions.forEach { (action) in
            alertSheet.addAction(action)
        }
        alertSheet.addAction(cancelAction)
    }
}
