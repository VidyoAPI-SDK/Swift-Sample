//
//  ScreenSharingAlertViewController.swift
//  Broadcast
//
//  Created by Marta Korol on 20.07.2021.
//

import UIKit
import ReplayKit
import CFNotificationCenterWrapper

class ScreenSharingAlertViewController: UIViewController {
    
    //MARK: - IBOutlets
    @IBOutlet weak var alertView: UIView!
    @IBOutlet weak var screenShareTitleLabel: UILabel!
    @IBOutlet weak var frameRateLabel: UILabel!
    @IBOutlet weak var labelContainerView: UIView!
    @IBOutlet weak var tableViewContainer: UIView!
    @IBOutlet weak var frameRateTableView: UITableView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var broadcastButtonContainerView: UIView!
    
    // MARK: - Const & vars
    private let notificationCenter = CFNotificationCenterWrapper()
    private let defaults = UserDefaults(suiteName: BroadcastExtensionConstants.applicationGroupIdentifier)!       
    private var frameRateModels = [
        FrameRateCellModel(type: .normal, isSelected: true),
        FrameRateCellModel(type: .high)
    ]
    
    var isHighFrameRate: Bool {
        guard let selected = frameRateModels.first(where: { $0.isSelected }) else {
            return false
        }
        return selected.type == .high
    }
    var isBroadcastStarted: Bool = false {
        didSet {
            updateMessage()
        }
    }
    
    //MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        addObservers()
        prepareUI()
        setupTableView()
        showBroadcastButton()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMessage()
        shareServices.isHighFrameRateShare = isHighFrameRate
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
    }
    
    //MARK: - IBActions
    @IBAction func closeButtonPressed(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    //MARK: - Functions
    @objc func onBroadcastStarted() {
        isBroadcastStarted = true
    }
    
    @objc func onBroadcastFinished() {
        isBroadcastStarted = false
    }
    
    private func addObservers() {
        observe(.shareBroadcastStarted, #selector(onBroadcastStarted))
        observe(.shareBroadcastFinished, #selector(onBroadcastFinished))
    }
    
    private func prepareUI() {
        alertView.layer.cornerRadius = 13
        frameRateLabel.text = BroadcastExtensionConstants.Screenshare.frameRateDescription
    }
    
    private func setupTableView() {
        frameRateTableView.delegate = self
        frameRateTableView.dataSource = self
        frameRateTableView.backgroundColor = UIColor.clear
        frameRateTableView.register(cellType: FrameRateTableViewCell.self)
        
        let footerWidth = frameRateTableView.frame.size.width
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: footerWidth, height: 1))
        frameRateTableView.tableFooterView = footer
    }
    
    private func showBroadcastButton() {
        isBroadcastStarted = defaults.object(forKey: BroadcastExtensionConstants.isBroadcastStarted) as? Bool ?? false
        
        let buttonRect = CGRect(origin: CGPoint.zero, size: broadcastButtonContainerView.bounds.size)
        let broadcastPicker = RPSystemBroadcastPickerView(frame: buttonRect)
        broadcastPicker.preferredExtension = BroadcastExtensionConstants.broascastExtensionBundleId
        broadcastPicker.showsMicrophoneButton = false
        
        broadcastButtonContainerView.addSubview(broadcastPicker)
    }
    
    private func showStartBrodcastingMessage() {
        labelContainerView.isHidden = false
        tableViewContainer.isHidden = false
        screenShareTitleLabel.text = BroadcastExtensionConstants.Screenshare.startScreenShareTitle
        messageLabel.text = BroadcastExtensionConstants.Screenshare.startScreenShareMessage
    }
    
    private func showStopBrodcastingMessage() {
        labelContainerView.isHidden = true
        tableViewContainer.isHidden = true
        screenShareTitleLabel.text = BroadcastExtensionConstants.Screenshare.stopScreenShareTitle
        messageLabel.text = BroadcastExtensionConstants.Screenshare.stopScreenShareMessage
    }
    
    private func updateMessage() {
        if isBroadcastStarted {
            showStopBrodcastingMessage()
        } else {
            showStartBrodcastingMessage()
        }
    }
    
    private func chooseFrameRate(forIndex index: Int) {
        frameRateModels = frameRateModels.map { var model = $0; model.isSelected = false; return model }
        frameRateModels[index].isSelected = true
        shareServices.isHighFrameRateShare = isHighFrameRate
    }
}

//MARK: - UITableViewDelegate & UITableViewDataSource
extension ScreenSharingAlertViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        frameRateModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  tableView.dequeueReusableCell(with: FrameRateTableViewCell.self, for: indexPath)
        cell.configure(with: frameRateModels[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.defaultHeightForRow
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        chooseFrameRate(forIndex: indexPath.row)
        tableView.reloadData()
    }
}
