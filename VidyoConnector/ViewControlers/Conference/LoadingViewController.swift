//
//  LoadingViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 01.06.2021.
//

import UIKit

class LoadingViewController: UIViewController {
    
    var loadingActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        
        indicator.style = .large
        indicator.color = .white
        indicator.startAnimating()
        indicator.autoresizingMask = [
            .flexibleLeftMargin, .flexibleRightMargin,
            .flexibleTopMargin, .flexibleBottomMargin
        ]
        
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)        
        loadingActivityIndicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view.addSubview(loadingActivityIndicator)
    }
    
    func dismiss() {
        loadingActivityIndicator.stopAnimating()
        dismiss(animated: true, completion: nil)
    }
    
    func startLoading() {
        if(!loadingActivityIndicator.isAnimating){
            loadingActivityIndicator.startAnimating()
        }
    }
}
