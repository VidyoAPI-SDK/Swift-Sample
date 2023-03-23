//
//  BaseJoinViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 31.05.2021.
//

import UIKit

class BaseJoinViewController: UIViewController {
    
    let connector = ConnectorManager.shared
    let loginToolbar = LoginToolbar.loadFromNib()
    var videoViewForConnector = UIView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setDelegates()
        addTapGestureRecognizerForKeyboardHiding()
        addObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupInitialViewOfUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updatePreview()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hidePreview()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updatePreview()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - Functions
    func setDelegates() {}
    func setupInitialViewOfUI() {}
    func refreshJoinButtonIfNeeded() {}
    
    @objc private func onBackgroundOpenned() {
        hidePreview()
    }
    
    @objc private func onBackgroundChose() {
        DispatchQueue.main.async {
            self.loginToolbar.updateBackgroundButton()
        }
        updatePreview()
    }
    
    func addObservers() {
        observe(.onBackgroundChose, #selector(onBackgroundChose))
        observe(.onBackgroundOpenned, #selector(onBackgroundOpenned))
    }
    
    func addToolbar() {
        loginToolbar.translatesAutoresizingMaskIntoConstraints = false
        loginToolbar.updatePreferenceImages()
        loginToolbar.presentNavigationControllerHandler = { [weak self] nc in
            self?.present(nc, animated: true, completion: nil)
        }
        navigationController?.toolbarItems = loginToolbar.items
        toolbarItems = navigationController?.toolbarItems
        navigationController?.toolbar.addSubview(loginToolbar)
    }
    
    func updatePreview() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connector.assignView(&self.videoViewForConnector, remoteParticipants: 0)
            self.connector.showLabel(false, for: &self.videoViewForConnector)
            self.connector.showView(for: &self.videoViewForConnector)
        }
    }
    
    func hidePreview() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connector.hideView(&self.videoViewForConnector)
        }
    }
    
    func presentConferenceVC(witData connectData: ConnectionData) {
        let factory = InstantiateFromStoryboardFactory()
        let conferenceVC: ConferenceViewController = factory.instantiateFromStoryboard()
        conferenceVC.connectParams = connectData
        conferenceVC.modalPresentationStyle = .fullScreen
        
        self.present(conferenceVC, animated: true, completion: nil)
    }
}

// MARK: - UITextFieldDelegate
extension BaseJoinViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let textField = textField as? LoginTextField else { return }
        textField.setActive()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let textField = textField as? LoginTextField else { return }
        textField.updateState()
        refreshJoinButtonIfNeeded()
    }
}
