//
//  ImagePicker.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 30.08.2021.
//

import UIKit

// MARK: - ImagePickerDelegate
protocol ImagePickerDelegate: class {
    func didSelect(image: UIImage?, path: String?)
}

// MARK: - ImagePicker
class ImagePicker: NSObject {
    private let pickerController = UIImagePickerController()
    private weak var presentationController: UIViewController?
    private weak var delegate: ImagePickerDelegate?
    
    // MARK: - Initialisation
    init(presentationController: UIViewController, delegate: ImagePickerDelegate) {
        super.init()
        self.delegate = delegate
        self.presentationController = presentationController
        
        self.pickerController.delegate = self
        self.pickerController.mediaTypes = ["public.image"]
    }
    
    // MARK: - Functions
    func present(from sourceView: UIView = UIView()) {
        pickerController.sourceType = .photoLibrary
        presentationController?.present(pickerController, animated: true)
    }
    
    private func pickerController(_ controller: UIImagePickerController, path: String?, didSelect image: UIImage?) {
        controller.dismiss(animated: true, completion: nil)
        delegate?.didSelect(image: image, path: path)
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension ImagePicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        pickerController(picker, path: nil, didSelect: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        guard
            let url = info[.imageURL] as? URL,
            let image = info[.originalImage] as? UIImage
        else {
            return pickerController(picker, path: nil, didSelect: nil)
        }
        pickerController(picker, path: url.absoluteURL.path, didSelect: image)
    }
}
