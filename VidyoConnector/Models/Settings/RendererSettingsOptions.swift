//
//  RendererSettingsOptions.swift
//  VidyoConnector-iOS
//
//  Created by Artem Dyavil on 28.05.2023.
//

enum RendererSettingsSectionHeaderTitle: String {
    case general = "General"
}

enum RendererType: String {
    case primary = "Default"
    case tile = "Tile"
    case ngr = "NGR"
}

enum LayoutType: String {
    case grid = "Grid"
    case speaker = "Speaker"
}

enum RendererSettingsOption: String, CaseIterable {
    case renderer = "Renderer"
    case layout = "Layout"
    case debugInfoVisible = "Visible debug info"
    case labelVisible = "Visible label"
    case audioMeterVisible = "Visible audio meter"
    case previewMirroringEnable = "Preview mirroring"
    case showAudioTiles = "Show audio tiles"
    case expandedCameraControl = "Expanded camera control"
    case feccIconCustomLayout = "Fecc icon custom layout"
    case verticalVideoCentering = "Vertical Video Centering"
    
    static var options = RendererSecondaryOptions()
}

struct RendererSecondaryOptions {
    var debugInfoVisible = defaultDebugInfoVisible()
    var labelVisible = defaultlabelVisible()
    var audioMeterVisible = defaultAudioMeterVisible()
    var previewMirroringEnable = defaultPreviewMirroringEnable()
    var showAudioTiles = defaultShowAudioTiles()
    var expandedCameraControl = defaultExpandedCameraControl()
    var feccIconCustomLayout = defaultFeccIconCustomLayout()
    var verticalVideoCentering = defaultCerticalVideoCentering()

    static private func defaultDebugInfoVisible() -> [OptionToChoose] {
        return [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: DefaultValuesManager.shared.debugInfoVisibility),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !DefaultValuesManager.shared.debugInfoVisibility)
        ]
    }
    
    static private func defaultlabelVisible() -> [OptionToChoose] {
        return [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: DefaultValuesManager.shared.labelVisibility),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !DefaultValuesManager.shared.labelVisibility)
        ]
    }
    
    static private func defaultAudioMeterVisible() -> [OptionToChoose] {
        return [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: DefaultValuesManager.shared.audioMeterVisibility),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !DefaultValuesManager.shared.audioMeterVisibility)
        ]
    }
    
    static private func defaultPreviewMirroringEnable() -> [OptionToChoose] {
        return [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: DefaultValuesManager.shared.previewMirroring),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !DefaultValuesManager.shared.previewMirroring)
        ]
    }
    
    static private func defaultShowAudioTiles() -> [OptionToChoose] {
        return [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: DefaultValuesManager.shared.showAudioTiles),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !DefaultValuesManager.shared.showAudioTiles)
        ]
    }
    
    static private func defaultExpandedCameraControl() -> [OptionToChoose] {
        return [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: DefaultValuesManager.shared.expandedCameraControl),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !DefaultValuesManager.shared.expandedCameraControl)
        ]
    }
    
    static private func defaultFeccIconCustomLayout() -> [OptionToChoose] {
        return [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: DefaultValuesManager.shared.feccIconCustomLayout),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !DefaultValuesManager.shared.feccIconCustomLayout)
        ]
    }
    
    static private func defaultCerticalVideoCentering() -> [OptionToChoose] {
        return [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: DefaultValuesManager.shared.verticalVideoCentering),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !DefaultValuesManager.shared.verticalVideoCentering)
        ]
    }
    
    var renderer: [OptionToChoose] {
        return [
            OptionToChoose(title: RendererType.primary.rawValue, isChosen: DefaultValuesManager.shared.renderer == RendererType.primary),
            OptionToChoose(title: RendererType.tile.rawValue, isChosen: DefaultValuesManager.shared.renderer == RendererType.tile),
            OptionToChoose(title: RendererType.ngr.rawValue, isChosen: DefaultValuesManager.shared.renderer == RendererType.ngr),
        ]
    }
    
    var layout: [OptionToChoose] {
        return [
            OptionToChoose(title: LayoutType.grid.rawValue, isChosen: DefaultValuesManager.shared.layout == LayoutType.grid),
            OptionToChoose(title: LayoutType.speaker.rawValue, isChosen: DefaultValuesManager.shared.layout == LayoutType.speaker)
        ]
    }

    func isSwitchOn(forTitle title: String) -> Bool {
        switch RendererSettingsOption(rawValue: title) {
            case .debugInfoVisible:
                return debugInfoVisible[0].isChosen
            case .labelVisible:
                return labelVisible[0].isChosen
            case .audioMeterVisible:
                return audioMeterVisible[0].isChosen
            case .previewMirroringEnable:
                return previewMirroringEnable[0].isChosen
            case .showAudioTiles:
                return showAudioTiles[0].isChosen
            case .expandedCameraControl:
                return expandedCameraControl[0].isChosen
            case .feccIconCustomLayout:
                return feccIconCustomLayout[0].isChosen
            case .verticalVideoCentering:
                return verticalVideoCentering[0].isChosen
            default:
                return false
        }
    }

    mutating func switchToggle(forTitle title: SettingsSwitchCell, withValue isOn: Bool) {
        let changedData = [
            OptionToChoose(title: SwitchOption.isOn.rawValue, isChosen: isOn),
            OptionToChoose(title: SwitchOption.isOff.rawValue, isChosen: !isOn)
        ]

        switch title {
            case .debugInfoVisible:
                debugInfoVisible = changedData
                DefaultValuesManager.shared.debugInfoVisibility = isOn
            case .labelVisible:
                labelVisible = changedData
                DefaultValuesManager.shared.labelVisibility = isOn
            case .audioMeterVisible:
                audioMeterVisible = changedData
                DefaultValuesManager.shared.audioMeterVisibility = isOn
            case .previewMirroringEnable:
                previewMirroringEnable = changedData
                DefaultValuesManager.shared.previewMirroring = isOn
            case .showAudioTiles:
                showAudioTiles = changedData
                DefaultValuesManager.shared.showAudioTiles = isOn
            case .expandedCameraControl:
                expandedCameraControl = changedData
                DefaultValuesManager.shared.expandedCameraControl = isOn
            case .feccIconCustomLayout:
                feccIconCustomLayout = changedData
                DefaultValuesManager.shared.feccIconCustomLayout = isOn
            case .verticalVideoCentering:
                verticalVideoCentering = changedData
                DefaultValuesManager.shared.verticalVideoCentering = isOn
            default:
                return
        }
    }
}
