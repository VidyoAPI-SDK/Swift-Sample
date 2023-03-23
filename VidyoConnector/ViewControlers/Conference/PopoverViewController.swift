//
//  PopoverViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 15.09.2021.
//

import Foundation

class PopoverViewController: UIViewController {
    
    private var messageLabel: UILabel = {
        let frame = CGRect(x: 0, y: 0, width: 300, height: 65)
        let label = UILabel(frame: frame)
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.numberOfLines = 0
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(messageLabel)
        preferredContentSize = messageLabel.frame.size
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func addMessage(_ message: String) {
        messageLabel.text = message
    }
}
