//
//  RendererOptionsTableViewController.swift
//  VidyoConnector-iOS
//
//  Created by Artem Dyavil on 27.05.2023.
//

import UIKit

class RendererOptionsTableViewController: UITableViewController {
    let settings = SettingsManager.shared
    var settingsType: SettingsOption!
    var mainOptions = [SettingsSection]()

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

    private func setDataForTableView() {
        guard let safeData = settings.getSettingsTableViewData(forChoice: settingsType) else {
            return
        }
        mainOptions = safeData
    }

    private func setupTableView() {
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = Constants.Color.settingsHeaderBackground
        tableView.register(cellType: SwitchTableViewCell.self)
        tableView.register(cellType: MainOptionTableViewCell.self)
    }

    private func updateTableViewData() {
        settings.updateSettingsTableViewData(forChoice: settingsType)
        setDataForTableView()
        tableView.reloadData()
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
}

extension RendererOptionsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        mainOptions.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return mainOptions[section].options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = mainOptions[indexPath.section].options[indexPath.row]

        switch model.accessType{
        case .toggle:
            let cell = tableView.dequeueReusableCell(with: SwitchTableViewCell.self, for: indexPath)
            cell.selectionStyle = .none
            cell.configure(with: model)
            cell.onSwitchChangedHandler = { [weak self] in
                guard let self = self else { return }
                self.settings.updateSettingsTableViewData(forChoice: self.settingsType)
                self.setDataForTableView()
                tableView.reloadRows(at: [indexPath], with: .none)
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
        
        let model = mainOptions[indexPath.section].options[indexPath.row]
        
        switch model.accessType {
        case .chose:
            pushChooseOptionViewController(withCellAccessType: .chose, title: model.title, for: indexPath)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = SettingsTableViewHeaderView()
        headerView.configure(with: mainOptions[section].headerTitle.rawValue.uppercased())
        return headerView
    }
}
