//
//  UITableView+RegisterCell.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 18.06.2021.
//

import UIKit

public extension UITableView {
    private func reuseIndentifier<T>(for type: T.Type) -> String {
        String(describing: type)
    }
    
    func register<T: UITableViewCell>(cellType: T.Type, bundle: Bundle? = nil) {
        let nib = UINib(nibName: reuseIndentifier(for: T.self), bundle: bundle)
        register(nib, forCellReuseIdentifier: reuseIndentifier(for: T.self))
    }

    func dequeueReusableCell<T: UITableViewCell>(with type: T.Type, for indexPath: IndexPath) -> T {
        guard let cell = dequeueReusableCell(withIdentifier: reuseIndentifier(for: T.self), for: indexPath) as? T else {
            fatalError("Failed to dequeue cell with identifier \(reuseIndentifier(for: T.self)).")
        }
        return cell
    }
}
