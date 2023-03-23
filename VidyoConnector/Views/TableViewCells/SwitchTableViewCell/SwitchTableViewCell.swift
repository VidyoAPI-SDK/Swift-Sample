//
//  SwitchTableViewCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 11.06.2021.
//

import UIKit

class SwitchTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var switchButton: UISwitch!
    
    var switchCellType: SettingsSwitchCell?
    var onSwitchChangedHandler: (() -> ())?
    
    override func prepareForReuse() {
        titleLabel.text = String()
        switchButton.isOn = false
    }
    
    @IBAction func switchStateChanged(_ sender: UISwitch) {
        handleToggle(withValue: sender.isOn)
        onSwitchChangedHandler?()
    }
    
    private func configure(withText text: String, isOn: Bool, isEnabled: Bool) {
        titleLabel.text = text
        switchButton.isOn = isOn
        isUserInteractionEnabled = isEnabled
        guard !isEnabled else { return }
        titleLabel.textColor = .lightGray
    }
    
    func configure(with cellModel: ChooseOptionCell) {
        if VideoSettingsOption(rawValue: cellModel.title) == .disableVideoOnPoorConnection {
            switchCellType = .disableVideoOnPoorConnection
            configure(withText: cellModel.title,
                      isOn: VideoSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        } else {
            configure(withText: cellModel.title,
                      isOn: GeneralSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
            
            let switchType = GeneralSettingsOption(rawValue: cellModel.title)
            switch switchType {
            case .enableAutoReconnect:
                switchCellType = .autoReconnect
            default: break
            }
        }
    }
    
    func handleToggle(withValue isOn: Bool) {
        switch switchCellType {
        case .autoReconnect:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .autoReconnect)
        case .disableVideoOnPoorConnection:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .disableVideoOnPoorConnection)
        case .none: return
        }
    }
}
