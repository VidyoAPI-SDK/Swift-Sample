//
//  ViewController.swift
//  VidyoConnector
//
//  Created by Marta Korol on 18.05.2021.
//

import UIKit

class JoinAsGuestViewController: BaseJoinViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var portalAddressTextField: LoginTextField!
    @IBOutlet weak var displayNameTextField: LoginTextField!
    @IBOutlet weak var roomKeyTextField: LoginTextField!
    @IBOutlet weak var roomPinTextField: LoginTextField!
    
    @IBOutlet weak var joinAsGuestButton: UIButton!
    @IBOutlet weak var joinAsRegisteredUserButton: UIButton!
    @IBOutlet weak var videoView: UIView!
     
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        videoViewForConnector = videoView
    }
    
    // MARK: - IBActions
    @IBAction func joinAsGuestButtonPressed(_ sender: UIButton) {
        let connectParams = GuestData(portalAddress: portalAddressTextField.text!,
                                      displayName: displayNameTextField.text!,
                                      roomKey: roomKeyTextField.text!,
                                      roomPin: roomPinTextField.text!)
        presentConferenceVC(witData: connectParams)
    }
    
    // MARK: - Functions
    override func setupInitialViewOfUI() {
        navigationController?.setNavigationBarHidden(true, animated: true)
        addToolbar()
        joinAsGuestButton.setup()
        joinAsRegisteredUserButton.setOpacity()
        videoView.layer.cornerRadius = 4
        refreshJoinButtonIfNeeded()
    }
    
    override func setDelegates() {
        portalAddressTextField.delegate = self
        displayNameTextField.delegate = self
        roomKeyTextField.delegate = self
        roomPinTextField.delegate = self
    }

    override func refreshJoinButtonIfNeeded() {
        guard
            portalAddressTextField != nil && portalAddressTextField.isNotEmpty,
            displayNameTextField != nil && displayNameTextField.isNotEmpty,
            roomKeyTextField != nil && roomKeyTextField.isNotEmpty,
            roomPinTextField != nil
        else {
            joinAsGuestButton.disable()
            return
        }
        joinAsGuestButton.enable()
    }
}
