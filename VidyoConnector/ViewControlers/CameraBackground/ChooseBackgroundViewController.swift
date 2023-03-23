//
//  ChooseBackgroundViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 27.08.2021.
//

import UIKit

class ChooseBackgroundViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var effectsCollectionView: UICollectionView!
    
    // MARK: - Const & vars
    let backgroundManager = CameraBackgroundManager.shared
    var imagePicker: ImagePicker!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareUI()
        setupCollectionView()
    }
    
    // MARK: - IBActions
    @IBAction func backButtonPressed(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Functions
    private func prepareUI() {
        contentView.layer.cornerRadius = 12
        imagePicker = ImagePicker(presentationController: self, delegate: self)
    }
    
    private func setupCollectionView() {
        effectsCollectionView.delegate = self
        effectsCollectionView.dataSource = self
        effectsCollectionView.register(BackgroundCollectionViewCell.nib,
                                       forCellWithReuseIdentifier: BackgroundCollectionViewCell.reuseIndentifier)
    }
}

// MARK: - ImagePickerDelegate
extension ChooseBackgroundViewController: ImagePickerDelegate {
    func didSelect(image: UIImage?, path: String?) {
        guard let image = image else { return }
        backgroundManager.updateUseYourImageModel(with: image, path: path)
        effectsCollectionView.reloadData()
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension ChooseBackgroundViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.frame.width/2.1
        let height = width*0.55
        return CGSize(width: width, height: height)
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension ChooseBackgroundViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        backgroundManager.modelsCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let model = backgroundManager.getModel(forIndex: indexPath.row)
        let cell = collectionView.dequeueReusableCell(with: BackgroundCollectionViewCell.self, for: indexPath)
        cell.configure(with: model)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let model = backgroundManager.getModel(forIndex: indexPath.row)
        switch model.type {
        case .photo:
            imagePicker.present()
        default:
            backgroundManager.selectModel(for: indexPath.row)
            collectionView.reloadData()
        }
    }
}
