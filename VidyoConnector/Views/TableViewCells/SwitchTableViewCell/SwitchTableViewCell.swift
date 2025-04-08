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
        } else if RendererSettingsOption(rawValue: cellModel.title) == .debugInfoVisible {
            switchCellType = .debugInfoVisible
            configure(withText: cellModel.title,
                      isOn: RendererSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        }  else if RendererSettingsOption(rawValue: cellModel.title) == .labelVisible {
            switchCellType = .labelVisible
            configure(withText: cellModel.title,
                      isOn: RendererSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        }  else if RendererSettingsOption(rawValue: cellModel.title) == .audioMeterVisible {
            switchCellType = .audioMeterVisible
            configure(withText: cellModel.title,
                      isOn: RendererSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        } else if RendererSettingsOption(rawValue: cellModel.title) == .previewMirroringEnable {
            switchCellType = .previewMirroringEnable
            configure(withText: cellModel.title,
                      isOn: RendererSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        } else if RendererSettingsOption(rawValue: cellModel.title) == .showAudioTiles {
            switchCellType = .showAudioTiles
            configure(withText: cellModel.title,
                      isOn: RendererSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        } else if RendererSettingsOption(rawValue: cellModel.title) == .expandedCameraControl {
            switchCellType = .expandedCameraControl
            configure(withText: cellModel.title,
                      isOn: RendererSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        } else if RendererSettingsOption(rawValue: cellModel.title) == .feccIconCustomLayout {
            switchCellType = .feccIconCustomLayout
            configure(withText: cellModel.title,
                      isOn: RendererSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        } else if RendererSettingsOption(rawValue: cellModel.title) == .verticalVideoCentering {
            switchCellType = .verticalVideoCentering
            configure(withText: cellModel.title,
                      isOn: RendererSettingsOption.options.isSwitchOn(forTitle: cellModel.title),
                      isEnabled: cellModel.isEnabled)
        }
        else {
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
        case .debugInfoVisible:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .debugInfoVisible)
        case .labelVisible:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .labelVisible)
        case .audioMeterVisible:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .audioMeterVisible)
        case .previewMirroringEnable:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .previewMirroringEnable)
        case .showAudioTiles:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .showAudioTiles)
        case .expandedCameraControl:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .expandedCameraControl)
        case .feccIconCustomLayout:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .feccIconCustomLayout)
        case .verticalVideoCentering:
            switchButton.isOn = SettingsManager.shared.setSwitchValueIfPossible(isOn, forCase: .verticalVideoCentering)
        case .none: return
        }
    }
}
