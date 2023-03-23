//
//  UICollectionView+RegisterCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 27.08.2021.
//

import Foundation

public extension UICollectionView {
    private func reuseIndentifier<T>(for type: T.Type) -> String {
        String(describing: type)
    }
    
    func register<T: UICollectionViewCell>(cellType: T.Type, bundle: Bundle? = nil) {
        let nib = UINib(nibName: reuseIndentifier(for: T.self), bundle: bundle)
        register(nib, forCellWithReuseIdentifier: reuseIndentifier(for: T.self))
    }

    func dequeueReusableCell<T: UICollectionViewCell>(with type: T.Type, for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withReuseIdentifier: reuseIndentifier(for: T.self), for: indexPath) as? T else {
            fatalError("Failed to dequeue cell with identifier \(reuseIndentifier(for: T.self)).")
        }
        return cell
    }
}
