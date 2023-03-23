//
//  InputValueViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 24.06.2021.
//

import UIKit

class InputValueViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var defaultValueLabel: UILabel!
    @IBOutlet weak var inputedValueLabel: UILabel!
    @IBOutlet weak var inputTextField: AnalyticsTextField!
    @IBOutlet weak var errorMessageLabel: UILabel!
    @IBOutlet weak var setButton: UIButton!
    
    // MARK: - Const & vars
    var options = [OptionToChoose]()
    var caseTitle = String()
    var settingsType: SettingsOption!
    var defaultValue: UInt32?
    var measurementUnit = String()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        addTapGestureRecognizerForKeyboardHiding()
    }
    
    // MARK: - IBActions
    @IBAction func setButtonPressed(_ sender: UIButton) {
        guard let value = inputTextField.text, !value.isEmpty else { return }
        saveDataIfPossible(withValue: value)
    }
    
    // MARK: - Functions
    private func setupUI() {
        title = caseTitle
        setButton.layer.cornerRadius = 4
        inputedValueLabel.isHidden = true
        errorMessageLabel.isHidden = true

        guard
            let safeDefaultValue = defaultValue,
            let safeMeasurementUnit = options.first?.title.letters
        else { return }
        
        measurementUnit = safeMeasurementUnit
        defaultValueLabel.text = "Default value is \(safeDefaultValue) \(measurementUnit)."
    }
    
    private func saveDataIfPossible(withValue value: String) {
        options = [OptionToChoose(title: "\(value) \(measurementUnit)", isChosen: true)]
        let isValueSet = SettingsManager.shared.setNewValuesIfPossible(
            forType: settingsType,
            forCase: caseTitle,
            withArray: options,
            optionIndex: 0
        )
        if isValueSet {
            log.info("Value successfully set.")
            inputedValueLabel.text = "\(value) \(measurementUnit) is set."
        } else {
            log.error("Failed to set value.")
            errorMessageLabel.text = "\(value) can't be set."
        }
        inputTextField.text = ""
        inputTextField.resignFirstResponder()
        errorMessageLabel.isHidden = isValueSet
        inputedValueLabel.isHidden = !isValueSet
    }
}
