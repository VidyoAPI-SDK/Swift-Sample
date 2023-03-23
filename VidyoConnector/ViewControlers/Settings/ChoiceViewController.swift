//
//  ChoiceViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 14.06.2021.
//

import UIKit

class ChoiceViewController: UIViewController {
    
    // MARK: - Const & vars
    private var pickerView: UIPickerView!
    private var tableView: UITableView!
    private var chosenOptionIndex: Int = 0
    private var previousSelectedValue: OptionToChoose?
    
    private var shoulSetNewValue: Bool {
        guard options[chosenOptionIndex] != previousSelectedValue else { return false }
        return true
    }
    
    var options = [OptionToChoose]()
    var caseTitle = String()
    var accessType: SettingsCellAccessType!
    var settingsType: SettingsOption!



    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = caseTitle
        view.backgroundColor = .systemBackground
        
        configureSubview()
        setCurrentOption()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveDataIfPossible()
    }
    
    // MARK: - Functions
    private func configureSubview() {
        switch accessType {
        case .chose:
            addTableViewAsSubview()
        case .pick:
            addPickerViewAsSubview()
        default: return
        }
    }
    
    private func setCurrentOption() {
        let currentOption = options.filter { $0.isChosen == true }
        guard !currentOption.isEmpty else { return }
        chosenOptionIndex = options.firstIndex(of: currentOption.first!)!
        previousSelectedValue = currentOption.first

        if accessType == .pick {
            pickerView.selectRow(chosenOptionIndex, inComponent: 0, animated: true)
        }
    }
    
    private func saveDataIfPossible() {
        savePickerData()
        guard shoulSetNewValue else {
            log.debug("Value wasn't changed.")
            return
        }
        let isValueSet = SettingsManager.shared.setNewValuesIfPossible(
            forType: settingsType,
            forCase: caseTitle,
            withArray: options,
            optionIndex: chosenOptionIndex
        )

        guard isValueSet else {
            log.error("Failed to set value.")
            return
        }
        log.debug("Value successfully set.")
    }
    
    private func savePickerData() {
        guard let picker = pickerView else { return }
        chosenOptionIndex = picker.selectedRow(inComponent: 0)
        changeChoosenOption(forIndex: chosenOptionIndex)
    }
    
    private func changeChoosenOption(forIndex index: Int) {
        options = options.map {
            var option = $0
            guard option.isChosen == true else { return option }
            option.isChosen = false
            return option
        }
        options[index].isChosen = true
    }
    
    private func setConstraints(forView subview: UIView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        subview.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        subview.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        view.rightAnchor.constraint(equalTo: subview.rightAnchor, constant: 0).isActive = true
        if subview == tableView {
            subview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true
        } else {
            subview.heightAnchor.constraint(equalToConstant: Constants.SettingsPickerView.height).isActive = true
        }
    }
}

//MARK: - UITableViewDelegate & UITableViewDataSource
extension ChoiceViewController: UITableViewDelegate, UITableViewDataSource {
    private func addTableViewAsSubview() {
        tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.tableFooterView = UIView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.TableViewCellID.optionCell)
        view.addSubview(tableView)
        setConstraints(forView: tableView)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.TableViewCellID.optionCell, for: indexPath)
        cell.textLabel?.text = options[indexPath.row].title
        cell.tintColor = Constants.Color.customLightGreen
        if options[indexPath.row].isChosen {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        changeChoosenOption(forIndex: indexPath.row)
        chosenOptionIndex = indexPath.row
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.defaultHeightForRow
    }
}

//MARK: - UIPickerViewDelegate & UIPickerViewDataSource
extension ChoiceViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    private func addPickerViewAsSubview() {
        pickerView = UIPickerView()
        pickerView.delegate = self
        pickerView.dataSource = self
        
        view.addSubview(pickerView)
        setConstraints(forView: pickerView)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return Constants.SettingsPickerView.numberOfComponents
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return options.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return options[row].title.digits
    }
    
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return Constants.SettingsPickerView.rowHeightForComponent
    }
}
