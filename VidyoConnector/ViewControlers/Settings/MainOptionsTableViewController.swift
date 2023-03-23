//
//  MainOptionsTableViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 12.06.2021.
//

import UIKit

class MainOptionsTableViewController: UITableViewController {
    
    // MARK: - Const & vars
    let settings = SettingsManager.shared
    var settingsType: SettingsOption!
    var mainOptions = [SettingsSection]()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = settingsType.rawValue
        setupTableView()
        setDataForTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTableViewData()
    }

    // MARK: - Functions
    private func setDataForTableView() {
        guard let safeData = settings.getSettingsTableViewData(forChoice: settingsType) else { return }
        mainOptions = safeData
    }
    
    private func setupTableView() {
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = Constants.Color.settingsHeaderBackground
        tableView.register(cellType: MainOptionTableViewCell.self)
        tableView.register(cellType: SwitchTableViewCell.self)
    }
    
    private func updateTableViewData() {
        settings.updateSettingsTableViewData(forChoice: settingsType)
        setDataForTableView()
        tableView.reloadData()
    }
    
    private func handleRowSelection(forIndexPath indexPath: IndexPath) {
        let cellData = mainOptions[indexPath.section].options[indexPath.row]
        switch cellData.accessType {
        case .chose:
            pushChooseOptionViewController(withCellAccessType: .chose, title: cellData.title, for: indexPath)
        case .pick:
            pushChooseOptionViewController(withCellAccessType: .pick, title: cellData.title, for: indexPath)
        case .input:
            pushInputValueViewController(for: cellData.title, with: indexPath)
        case .googleAnalitycs:
            pushGoogleAnalyticsViewController(with: cellData)
        case .vidyoInsight:
            pushVidyoInsightViewController(with: cellData)
        case .toggle:
            return
        }
    }
    
    private func pushChooseOptionViewController(withCellAccessType accessType: SettingsCellAccessType, title: String, for indexPath: IndexPath) {
        let choiceVC = ChoiceViewController()
        choiceVC.accessType = accessType
        choiceVC.settingsType = settingsType
        choiceVC.caseTitle = title
        
        let optionToChoose = settings.getOptionsToChoose(forChoice: settingsType, title: title)
        guard let safeOption = optionToChoose else { return }
        choiceVC.options = safeOption
        
        self.navigationController?.pushViewController(choiceVC, animated: true)
    }
    
    private func pushGoogleAnalyticsViewController(with cellData: ChooseOptionCell) {
        let factory = InstantiateFromStoryboardFactory()
        let analyticsVC: GoogleAnalyticsViewController = factory.instantiateFromStoryboard()
        navigationController?.pushViewController(analyticsVC, animated: true)
    }
    
    private func pushVidyoInsightViewController(with cellData: ChooseOptionCell) {
        let factory = InstantiateFromStoryboardFactory()
        let analyticsVC: VidyoInsightViewController = factory.instantiateFromStoryboard()
        navigationController?.pushViewController(analyticsVC, animated: true)
    }
    
    private func pushInputValueViewController(for title: String, with indexPath: IndexPath) {
        let optionToChoose = settings.getOptionsToChoose(forChoice: settingsType, title: title)
        let inputValueVC: InputValueViewController = InstantiateFromStoryboardFactory().instantiateFromStoryboard()
        inputValueVC.settingsType = settingsType
        inputValueVC.caseTitle = title
        inputValueVC.defaultValue = settings.getDefaultValue(forChoice: settingsType, title: title)
        
        guard let options = optionToChoose else { return }
        inputValueVC.options = options
        
        self.navigationController?.pushViewController(inputValueVC, animated: true)
    }
}

// MARK: - TableViewDelegate & TableViewDataSource
extension MainOptionsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        mainOptions.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mainOptions[section].options.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = mainOptions[indexPath.section].options[indexPath.row]
        
        switch model.accessType {
        case .toggle:
            let cell = tableView.dequeueReusableCell(with: SwitchTableViewCell.self, for: indexPath)
            cell.configure(with: model)
            cell.onSwitchChangedHandler = { [weak self] in
                self?.updateTableViewData()
            }
            return cell
            
        default:
            let cell = tableView.dequeueReusableCell(with: MainOptionTableViewCell.self, for: indexPath)
            cell.configure(with: model)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Constants.SettingsTableView.heightForHeader
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.defaultHeightForRow
    }
        
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        handleRowSelection(forIndexPath: indexPath)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = SettingsTableViewHeaderView()
        headerView.configure(with: mainOptions[section].headerTitle.rawValue.uppercased())
        return headerView
    }
}
