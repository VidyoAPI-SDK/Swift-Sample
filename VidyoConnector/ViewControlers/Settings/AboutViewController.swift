//
//  AboutViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 03.09.2021.
//

import UIKit

class AboutViewController: UIViewController {
    private struct VidyoInfo {
        static let websiteLink = "https://www.vidyo.com/company/patent-notices"
        static let attributionsLink = "http://www.vidyo.com/wp-content/uploads/Vidyo-OSS-Attributions.pdf"
        
        static let websiteLinkText = "the Patent Notice page of Vidyo's website"
        static let attributionsLinkText = "Vidyo OSS Attributions"
       
        static let versionFormat = "Version %@"
        static let copyrightFormat = "Copyright © 2010 – %@ Vidyo, Inc."
    }

    // MARK: - IBOutlets
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var copyrightLabel: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    
    // MARK: - Const & vars
    let connector = ConnectorManager.shared
    
    var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareUI()
    }
   
    // MARK: - Functions
    private func prepareUI() {
        title = SettingsOption.about.rawValue
        
        versionLabel.text = String(format: VidyoInfo.versionFormat, connector.version)
        copyrightLabel.text = String(format: VidyoInfo.copyrightFormat, currentYear)
        
        setLinks()
    }
    
    private func setLinks() {
        let linkedText = NSMutableAttributedString(attributedString: descriptionTextView.attributedText)
        linkedText.setFirstOccurrenceTextAsLink(VidyoInfo.websiteLink, text: VidyoInfo.websiteLinkText)
        linkedText.setFirstOccurrenceTextAsLink(VidyoInfo.attributionsLink, text: VidyoInfo.attributionsLinkText)
        
        descriptionTextView.attributedText = NSAttributedString(attributedString: linkedText)
        descriptionTextView.linkTextAttributes = NSMutableAttributedString.linkTextAttributes
    }
    
    private func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return true
    }
}
