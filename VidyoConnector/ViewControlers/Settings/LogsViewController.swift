//
//  LogsViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 12.07.2021.
//

import UIKit

class LogsViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var logLevelButton: UIButton!
    @IBOutlet weak var customLogLevelStackView: UIStackView!
    @IBOutlet weak var advancedFilterTextField: AnalyticsTextField!
    @IBOutlet weak var applyButton: UIButton!
    @IBOutlet weak var logsTextView: UITextView!
    
    // MARK: - Const & vars
    let logsManager = SettingsManager.shared.logsManager
    var settingsType = SettingsOption.logs
    
    private var logLevelTitle: String {
        return LogLevelOptions.getCurrentLogLevel()
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareUI()
        addTapGestureRecognizerForKeyboardHiding()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
        updateLogsIfNeeded()
    }
    
    // MARK: - IBActions
    @IBAction func chooseLogLevelButtonPressed(_ sender: UIButton) {
        pushChoiceViewController()
    }
    
    @IBAction func applyButtonPressed(_ sender: UIButton) {
        guard let filter = advancedFilterTextField.text, !filter.isEmpty else {
            log.error("Filter is nil or empty.")
            return
        }
        let success = logsManager.setAdvancedLogOptions(filter: filter)
        log.info("setAdvancedLogOptions returned \(success)")
        showMessageForAdvancedFilter(withResult: success)
        updateLogsIfNeeded()
    }
    
    @IBAction func displayLogsButtonPressed(_ sender: UIButton) {
        logsTextView.isHidden = !logsTextView.isHidden
        updateLogsIfNeeded()
    }
    
    // MARK: - Functions
    private func prepareUI() {
        title = settingsType.rawValue
        logsTextView.isHidden = true
        applyButton.layer.cornerRadius = 4
        advancedFilterTextField.delegate = self
    }
    
    private func updateUI() {
        logLevelButton.setTitle("\(logLevelTitle) \t", for: .normal)
        switch logLevelTitle {
        case LogLevel.debug.rawValue:
            customLogLevelStackView.isHidden = true
        case LogLevel.production.rawValue:
            customLogLevelStackView.isHidden = true
        case LogLevel.advanced.rawValue:
            customLogLevelStackView.isHidden = false
        default: return
        }
    }
    
    private func updateLogsIfNeeded() {
        guard !logsTextView.isHidden else { return }
        guard let logsFromFile = logsManager.getLogsFromFile() else { return }
        logsTextView.text = logsFromFile
    }
    
    private func pushChoiceViewController() {
        let choiceVC = ChoiceViewController()
        
        choiceVC.accessType = .chose
        choiceVC.settingsType = settingsType
        choiceVC.caseTitle = "Log Level"
        choiceVC.options = LogLevelOptions.options
        
        self.navigationController?.pushViewController(choiceVC, animated: true)
    }
    
    private func showMessageForAdvancedFilter(withResult success: Bool) {
        guard success else { return }
        advancedFilterTextField.text = ""
        advancedFilterTextField.resignFirstResponder()
        showSuccess(withMessage: "Successfully applied changes")
    }
    
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
extension LogsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
