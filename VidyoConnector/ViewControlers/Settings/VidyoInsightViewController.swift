//
//  VidyoInsightViewController.swift
//  VidyoConnector
//
//  Created by Amit Gemini on 25/07/22.
//

import UIKit

class VidyoInsightViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var serverUrlTextField: AnalyticsTextField!
    @IBOutlet weak var errorMessageLabel: UILabel!
    @IBOutlet weak var startVidyoInsightButton : UIButton!
    @IBOutlet weak var stopVidyoInsightButton : UIButton!
    
    // MARK: - Const & vars
    let generalSettings = GeneralSettingsOption.options
    let analyticsManager = SettingsManager.shared.analyticsManager
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Vidyo Insight"
        serverUrlTextField.delegate = self
        descriptionLabel.text = " IP Address or URL"
        serverUrlTextField.text = analyticsManager.isInsightsServiceEnabled() == true ? String(analyticsManager.getInsightsServiceUrl()) : ""
        
        enableStartButton(!analyticsManager.isInsightsServiceEnabled());
        enableStopButton(analyticsManager.isInsightsServiceEnabled());
    }
    
    func checkIPAddressOrURL() -> Bool {
        guard let text = serverUrlTextField.text, !text.isEmpty else { return false }
        guard text.isURL || text.isIpAddress else {
            errorMessageLabel.text = " The IP Address or URL is invalid."
            errorMessageLabel.isHidden = false
            return false
        }
        return true
    }
    
    //MARK:- Start Action
    @IBAction func startVidyoInsight(_ sender : UIButton){
        guard (checkIPAddressOrURL()) else {
            return
        }
        
        if(!analyticsManager.startInsightsService(withEnteredData: serverUrlTextField.text ?? "")) {
            errorMessageLabel.text = " Failed to start vidyo insight service."
            errorMessageLabel.isHidden = false
        }
        else {
            errorMessageLabel.isHidden = true
            enableStartButton(false);
            enableStopButton(true);
            serverUrlTextField.text = String(analyticsManager.getInsightsServiceUrl())
        }
    }
    
    //MARK:- Stop Action
    @IBAction func stopVidyoInsight(_ sender : UIButton){
        if(!analyticsManager.stopInsightsService()) {
            errorMessageLabel.text = " Failed to stop vidyo insight service."
            errorMessageLabel.isHidden = false
        }
        else {
            errorMessageLabel.isHidden = true
            enableStartButton(true);
            enableStopButton(false);
        }
    }
    
    func enableStartButton(_ enable : Bool){
        startVidyoInsightButton.isUserInteractionEnabled = enable
        startVidyoInsightButton.alpha = enable ? 1.0 : 0.5
    }
    
    func enableStopButton(_ enable : Bool){
        stopVidyoInsightButton.isUserInteractionEnabled = enable
        stopVidyoInsightButton.alpha = enable ? 1.0 : 0.5
        if(!enable) {
            serverUrlTextField.text = ""
        }
    }
    
    // // MARK: - Functions
    private func showSuccess(withMessage message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)
        let dismissAlert = DispatchWorkItem {
            alert.dismiss(animated: true, completion: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: dismissAlert)
    }
}
    
// MARK: - UITextFieldDelegate
extension VidyoInsightViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        errorMessageLabel.isHidden = true
        return true
    }
}
