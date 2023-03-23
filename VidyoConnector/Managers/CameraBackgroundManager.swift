//
//  CameraBackgroundManager.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 30.08.2021.
//

import Foundation

class CameraBackgroundManager {
    
    static let shared = CameraBackgroundManager()
    
    private let connector = ConnectorManager.shared
    private let defaultModel: BackgroundModel
    private var models = [BackgroundModel]()
    private var currentEffectType: VCConnectorCameraEffectType = .none
    
    private var selectedModel: BackgroundModel? {
        models.first(where: { $0.isSelected })
    }
    var modelsCount: Int {
        models.count
    }
    var selectedImage: UIImage? {
        guard let model = selectedModel else { return nil }
        return model.image
    }
    
    // MARK: - Initialisation
    private init() {
        defaultModel = BackgroundModel(
            type: .none,
            image: UIImage(named: Constants.Icon.none),
            isSelected: true
        )
        populateModels()
    }
    
    // MARK: - Methods
    func getModel(forIndex index: Int) -> BackgroundModel {
        guard index < modelsCount else { return defaultModel }
        return models[index]
    }
    
    func updateUseYourImageModel(with image: UIImage, path: String?) {
        unselectItems()
        guard let index = models.firstIndex(where: { $0.type == .photo }) else {
            log.error("Cannot find model with type: \(BackgroundType.photo.rawValue).")
            return
        }
        models[index] = BackgroundModel(type: .photo, image: image, path: path, title: "", isSelected: true)
    }
    
    func selectModel(for index: Int) {
        unselectItems()
        models[index].isSelected = true
        guard let index = models.firstIndex(where: { $0.type == .photo }) else {
            log.error("Cannot find model with type: \(BackgroundType.photo.rawValue).")
            return
        }
        models[index] = BackgroundModel(type: .photo)
    }
    
    func setEffect() -> Bool {
        var isEffectSet = false
        
        guard let model = selectedModel else { return isEffectSet }        
        switch model.type {
        case .none:
            isEffectSet = setBackgroundEffect(type: .none)
        case .blur:
            isEffectSet = setBackgroundEffect(type: .blur)
            if !isEffectSet {
                log.error("Cannot set blur background effect.")
            }
        default:
            guard let path = model.path else { return isEffectSet }
            isEffectSet = setVirtualBackground(picturePath: path)
            if !isEffectSet {
                log.error("Cannot set virtual background effect or change picture.")
            }
        }
        // Set "none" when failed to set effect
        if !isEffectSet, currentEffectType != .none {
            isEffectSet = setBackgroundEffect(type: .none)
        }
        
        return isEffectSet
    }
    
    private func populateModels() {
        models = [
            defaultModel,
            BackgroundModel(type: .photo),
            BackgroundModel(type: .blur, image: UIImage(named: Constants.Icon.blur))
        ]
        Constants.IconBG.allCases.forEach { iconTitle in
            let image = UIImage(named: iconTitle.rawValue)
            let path = String(format: BackgroundResoursesConstants.imagePathFormat, iconTitle.rawValue)
            models.append(BackgroundModel(type: .image, image: image, path: path))
        }
    }
    
    private func unselectItems() {
        models = models.map {
            guard $0.isSelected else { return $0 }
            var model = $0
            model.isSelected = false
            return model
        }
    }
    
    private func setBackgroundEffect(type: VCConnectorCameraEffectType) -> Bool {
        let isSet = connector.setCameraBackgroundEffect(type)
        guard isSet else { return isSet }
        currentEffectType = type
        return isSet
    }
    
    private func setVirtualBackground(picturePath: String) -> Bool {
        var isSet: Bool
        if currentEffectType != .virtualBackground {
            isSet = connector.setCameraBackgroundEffect(.virtualBackground, picturePath: picturePath)
            guard isSet else { return isSet }
            currentEffectType = .virtualBackground
        } else {
            isSet = connector.setVirtualBackgroundPicture(picturePath: picturePath)
        }
        return isSet
    }
}
