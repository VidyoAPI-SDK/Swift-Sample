//
//  BaseJoinViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 31.05.2021.
//

import UIKit

class BaseJoinViewController: UIViewController {
    
    let renderer = RendererManager.shared
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
        SettingsManager.shared.setDelegate(loginToolbar)
    }
    
    func updateViewSize() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.renderer.setViewSize(&self.videoViewForConnector, self.videoViewForConnector.frame)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.renderer.showPreviewView(&self.videoViewForConnector)
        updateViewSize()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.renderer.hideView(&self.videoViewForConnector)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateViewSize()
    }
    
    deinit {
        removeObservers()
    }
    
    // MARK: - Functions
    func setDelegates() {}
    func setupInitialViewOfUI() {}
    func refreshJoinButtonIfNeeded() {}
    
    @objc private func onBackgroundChose() {
        DispatchQueue.main.async {
            self.loginToolbar.updateBackgroundButton()
        }
    }
    
    func addObservers() {
        observe(.onBackgroundChose, #selector(onBackgroundChose))
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
