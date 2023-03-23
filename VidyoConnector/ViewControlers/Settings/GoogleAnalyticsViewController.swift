//
//  GoogleAnalyticsViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 16.06.2021.
//

import UIKit
import os

class GoogleAnalyticsViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var googleanalyticIdTextField: AnalyticsTextField!
    @IBOutlet weak var errorMessageLabel: UILabel!
    
    @IBOutlet weak var googleAnalyticsEventsView: UIView!
    @IBOutlet weak var eventsTableView: UITableView!
    @IBOutlet weak var applyButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var startGoogleAnalyticsButton : UIButton!
    @IBOutlet weak var stopGoogleAnalyticsButton : UIButton!
        
    // MARK: - Const & vars
    let generalSettings = GeneralSettingsOption.options
    let analyticsManager = SettingsManager.shared.analyticsManager
    var events = AnalyticsEventTable.eventaTable
    var changedEvents = [GoogleAnalyticsEvent]()
        
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Google Analytics"
        
        googleanalyticIdTextField.delegate = self
        applyButton.layer.cornerRadius = 4
        
        setupTableView()
        descriptionLabel.text = " Web Property ID"
        googleanalyticIdTextField.text = analyticsManager.isGoogleAnalyticsServiceEnabled() == true ? String(analyticsManager.getGoogleAnalyticsServiceId()) : ""
        
        enableStartButton(!analyticsManager.isGoogleAnalyticsServiceEnabled());
        enableStopButton(analyticsManager.isGoogleAnalyticsServiceEnabled());
    }
    
    //MARK:- Start Action
    @IBAction func startGoogleAnalytics(_ sender : UIButton) {
        var googleAnalyticId = ""
        
        if(googleanalyticIdTextField.text?.isEmpty == true) {
            googleAnalyticId = AnalyticsManager.getDefaultGoogleAnalyticId()
        }
        else {
            googleAnalyticId = googleanalyticIdTextField.text!
        }
        
        if(!analyticsManager.startGoogleAnalyticsService(withEnteredData: googleAnalyticId)) {
            errorMessageLabel.text = " Failed to start google analytics service."
            errorMessageLabel.isHidden = false
        }
        else {
            enableStartButton(false);
            enableStopButton(true);
            googleanalyticIdTextField.text = String(analyticsManager.getGoogleAnalyticsServiceId())
            errorMessageLabel.isHidden = true
        }
    }
    
    //MARK:- Stop Action
    @IBAction func stopGoogleAnalytics(_ sender : UIButton){
        if(!analyticsManager.stopGoogleAnalyticsService()) {
            errorMessageLabel.text = " Failed to stop google analytics service."
            errorMessageLabel.isHidden = false
        }
        else {
            enableStartButton(true);
            enableStopButton(false);
            errorMessageLabel.isHidden = true
        }
    }
    
    func enableStartButton(_ enable : Bool){
        startGoogleAnalyticsButton.isUserInteractionEnabled = enable
        startGoogleAnalyticsButton.alpha = enable ? 1.0 : 0.5
        googleanalyticIdTextField.isUserInteractionEnabled = enable
    }
    
    func enableStopButton(_ enable : Bool){
        stopGoogleAnalyticsButton.isUserInteractionEnabled = enable
        stopGoogleAnalyticsButton.alpha = enable ? 1.0 : 0.5
        if(!enable) {
            googleanalyticIdTextField.text = ""
        }
    }
    
    // MARK: - IBActions
    @IBAction func applyButtonPressed(_ sender: UIButton) {
        var success = true
        for event in changedEvents {
            let isChanged = analyticsManager.controlGoogleAnalyticsEventAction(event.eventCategory, event.eventAction, event.isEnabled)
            if !isChanged {
                success = false
                guard let index = events.firstIndex(of: event) else { return }
                events[index].changeEnabledStatus()
            }
        }
        AnalyticsEventTable.eventaTable = events
        changedEvents = [GoogleAnalyticsEvent]()
        
        showMessageForEvent(withResult: success)
        eventsTableView.reloadData()
    }
    
    @IBAction func cancelButtonPressed(_ sender: UIButton) {
        errorMessageLabel.isHidden = true
        events = AnalyticsEventTable.eventaTable
        changedEvents = [GoogleAnalyticsEvent]()
        eventsTableView.reloadData()
    }
    
    // MARK: - Functions
    
    private func setupTableView() {
        eventsTableView.delegate = self
        eventsTableView.dataSource = self
        eventsTableView.tableFooterView = UIView()
        eventsTableView.separatorInset = .zero
        eventsTableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.TableViewCellID.googleAnalyticsCell)
    }
    
    private func showMessageForEvent(withResult success: Bool) {
        if success {
            let text = "Successfully applied changes"
            showSuccess(withMessage: text)
        } else {
            errorMessageLabel.text = " Some changes didn't be set. Try again."
            errorMessageLabel.isHidden = false
        }
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

//MARK: - UITableViewDelegate & UITableViewDataSource
extension GoogleAnalyticsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: Constants.TableViewCellID.googleAnalyticsCell)
        cell.tintColor = Constants.Color.customLightGreen
        cell.textLabel?.text = events[indexPath.row].title.rawValue
        cell.detailTextLabel?.text = events[indexPath.row].subtitle.rawValue
        cell.detailTextLabel?.textColor = .gray

        if events[indexPath.row].isEnabled {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.SettingsTableView.heightForAnalyticsRow
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        errorMessageLabel.isHidden = true
        
        events[indexPath.row].changeEnabledStatus()
        changedEvents.append(events[indexPath.row])
        
        if events[indexPath.row].isEnabled {
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        } else {
            tableView.cellForRow(at: indexPath)?.accessoryType = .none
        }
    }
}

// MARK: - UITextFieldDelegate
extension GoogleAnalyticsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.isEmpty else { return false }
        errorMessageLabel.isHidden = true
        return true
    }
}
