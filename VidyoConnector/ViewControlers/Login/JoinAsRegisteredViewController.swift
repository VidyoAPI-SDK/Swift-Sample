//
//  JoinAsRegisteredViewController.swift
//  VidyoConnector
//
//  Created by Marta Korol on 19.05.2021.
//

import UIKit

class JoinAsRegisteredViewController: BaseJoinViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var portalAddressTextField: LoginTextField!
    @IBOutlet weak var usernameTextField: LoginTextField!
    @IBOutlet weak var passwordTextField: LoginTextField!
    @IBOutlet weak var roomKeyTextField: LoginTextField!
    @IBOutlet weak var roomPinTextField: LoginTextField!
    
    @IBOutlet weak var joinAsRegisteredUserButton: UIButton!
    @IBOutlet weak var videoView: UIView!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        videoViewForConnector = videoView
    }
    
    // MARK: - IBActions
    @IBAction func joinAsRegisteredUserButtonPressed(_ sender: UIButton) {
        let connectParams = UserData(portalAddress: portalAddressTextField.text!,
                                     username: usernameTextField.text!,
                                     password: passwordTextField.text!,
                                     roomKey: roomKeyTextField.text!,
                                     roomPin: roomPinTextField.text!)
        presentConferenceVC(witData: connectParams)
    }
    
    // MARK: - Functions
    @objc func backAction(_ sender: UIButton) {
       navigationController?.popViewController(animated: true)
    }
    
    private func addBackButton() {
        let imageConfig =  UIImage.SymbolConfiguration(pointSize: UIFont.systemFontSize, weight: .medium, scale: .large)
        let buttonImage = UIImage(systemName: Constants.SystemImage.back, withConfiguration: imageConfig)
        let backButton = UIButton(type: .custom)
                
        backButton.setTitle("", for: .normal)
        backButton.setImage(buttonImage, for: .normal)
        backButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
        backButton.addTarget(self, action: #selector(backAction), for: .touchUpInside)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
    }

    private func setupNavigationController() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        
        addToolbar()
        addBackButton()
    }
    
    override func setupInitialViewOfUI() {
        setupNavigationController()
        joinAsRegisteredUserButton.setup()
        videoView.layer.cornerRadius = 4
        refreshJoinButtonIfNeeded()
    }
   
    override func setDelegates() {
        portalAddressTextField.delegate = self
        usernameTextField.delegate = self
        passwordTextField.delegate = self
        roomKeyTextField.delegate = self
        roomPinTextField.delegate = self
    }
    
    override func refreshJoinButtonIfNeeded() {
        guard
            portalAddressTextField != nil && portalAddressTextField.isNotEmpty,
            usernameTextField != nil && usernameTextField.isNotEmpty,
            passwordTextField != nil && passwordTextField.isNotEmpty,
            roomKeyTextField != nil && roomKeyTextField.isNotEmpty,
            roomPinTextField != nil
        else {
            joinAsRegisteredUserButton.disable()
            return
        }
        joinAsRegisteredUserButton.enable()
    }
}
