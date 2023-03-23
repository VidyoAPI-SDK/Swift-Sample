//
//  BackgroundPreviewViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 27.08.2021.
//

import UIKit

class BackgroundPreviewViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var currentBgImageView: UIImageView!
    
    // MARK: - Const & vars
    let connector = ConnectorManager.shared
    let backgroundManager = CameraBackgroundManager.shared
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setEffect()
        updatePreview()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updatePreview()
    }
    
    // MARK: - IBActions
    @IBAction func chooseBackgroundButtonPressed(_ sender: UIButton) {
        let factory = InstantiateFromStoryboardFactory()
        let vc: ChooseBackgroundViewController = factory.instantiateFromStoryboard()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func closeButtonPressed(_ sender: UIButton) {
        self.connector.hideView(&self.videoView)
        NotificationCenter.default.post(name: .onBackgroundChose, object: nil)
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Functions
    private func prepareUI() {
        currentBgImageView.layer.borderColor = UIColor.lightGray.cgColor
        currentBgImageView.layer.borderWidth = 0.5
        currentBgImageView.layer.cornerRadius = 2
        contentView.layer.cornerRadius = 12
        videoView.layer.cornerRadius = 4
    }
    
    private func updatePreview() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connector.assignView(&self.videoView, remoteParticipants: 0)
            self.connector.showView(for: &self.videoView)
            self.connector.showLabel(false, for: &self.videoView)
            self.connector.showAudioMeters(false, for: &self.videoView)
        }
    }
    
    private func setEffect() {
        if !backgroundManager.setEffect() {
            log.error("Camera background effect didn't set.")
        }
        currentBgImageView.image = backgroundManager.selectedImage
    }
}
