//
//  SettingsTableViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 09.06.2021.
//

import UIKit

class SettingsTableViewController: UITableViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var closeBarButton: UIBarButtonItem!

    // MARK: - Const & vars
    let settingsMainOptions = SettingsManager.shared.getMainOptinsData()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
    }
    
    // MARK: - IBActions
    @IBAction func closeButtonPressed(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }    
    
    // MARK: - Functions
    private func setupTableView() {
        tableView.tableFooterView = UIView()
        tableView.register(cellType: SettingsTableViewCell.self)
    }
    
    private func pushMainOptionsTableViewController(forIndex index: Int) {
        let factory = InstantiateFromStoryboardFactory()
        let vc: MainOptionsTableViewController = factory.instantiateFromStoryboard()
        vc.settingsType = settingsMainOptions[index].title
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func pushViewController<T:UIViewController>(type: T.Type) {
        let vc: T = InstantiateFromStoryboardFactory().instantiateFromStoryboard()
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - TableViewDelegate & TableViewDataSource
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsMainOptions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  tableView.dequeueReusableCell(with: SettingsTableViewCell.self, for: indexPath)
        cell.configure(with: settingsMainOptions[indexPath.row])
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.defaultHeightForRow
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch settingsMainOptions[indexPath.row].title {
        case .general, .audio, .video:
            pushMainOptionsTableViewController(forIndex: indexPath.row)
        case .logs:
            pushViewController(type: LogsViewController.self)
        case .about:
            pushViewController(type: AboutViewController.self)
        default:
            log.info("Ooops, found unreachable option for now.")
        }
    }
}
