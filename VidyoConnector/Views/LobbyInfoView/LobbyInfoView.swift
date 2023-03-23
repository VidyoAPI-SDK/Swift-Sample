//
//  LobbyInfoView.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 19.09.2021.
//

import UIKit

class LobbyInfoView: UIView {

    // MARK: - IBOutlets
    @IBOutlet weak private var timerContainerView: UIView!
    @IBOutlet weak private var timeLabel: UILabel!
    @IBOutlet weak private var roomNameLabel: UILabel!
    @IBOutlet weak private var hostNameLabel: UILabel!
    @IBOutlet weak private var joinCallButton: UIButton!
    
    private var circularProgressBarView: CircularProgressBarView!
    private var timeInterval: TimeInterval = 5
    private var timer = Timer()
    
    var onConferenceAvailableHandler: (() -> ())?
    
    var isLobbyMode = true {
        didSet {
            updateUI()
        }
    }
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        prepareUI()
    }
        
    // MARK: - IBActions
    @IBAction func joinCallButtonPressed(_ sender: UIButton) {
        onConferenceAvailableHandler?()
    }
    
    // MARK: - Methods
    @objc private func fireTimer() {
        if timeInterval < 1 {
            onConferenceAvailableHandler?()
            timer.invalidate()
            timeLabel.isHidden = true
            timeInterval = 5
        } else {
            timeLabel.isHidden = false
            timeLabel.text = String(format: "%.0f", timeInterval)
            timeInterval -= 1
        }
    }
    
    private func prepareUI() {
        joinCallButton.layer.cornerRadius = 4
        roomNameLabel.text = nil
        hostNameLabel.text = nil
        
        setUpCircularProgressBarView()
        updateUI()
    }
    
    private func setUpCircularProgressBarView() {
        circularProgressBarView = CircularProgressBarView(frame: timerContainerView.bounds)
        timerContainerView.addSubview(circularProgressBarView)
        layoutSubviews()
    }
    
    private func updateUI() {
        timerContainerView.isHidden = isLobbyMode
        joinCallButton.isHidden = isLobbyMode
    }
    
    func setInfo(roomName: String, hostName: String = "") {
        roomNameLabel.text = roomName
        hostNameLabel.text = hostName
    }
    
    func startCountdown() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        circularProgressBarView.progressAnimation(duration: timeInterval)
        timer.fire()
    }
}
