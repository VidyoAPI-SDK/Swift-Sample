//
//  ChatListViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 11.08.2021.
//

import UIKit

class ChatListViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var chatSearchTextField: ChatSearchTextField!
    @IBOutlet weak var cancelSearchButton: UIButton!
    @IBOutlet weak var chatListTableView: UITableView!
    @IBOutlet weak var closeBarButton: UIBarButtonItem!
    
    // MARK: - Const & vars
    private var filteredChatList = [Chat]()
    var messagingManager: MessagingManager?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareUI()
        setupTableView()
        prepareChatMenagerHandlers()
        
        filteredChatList = chatManager.chatList
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateChatList()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        addObservers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
    }
    
    // MARK: - IBActions
    @IBAction func closeBarButtonPressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelSearchButtonPressed(_ sender: UIButton) {
        filteredChatList = chatManager.chatList
        chatListTableView.reloadData()
        chatSearchTextField.text = nil
        cancelSearchButton.isHidden = true
        chatSearchTextField.resignFirstResponder()
    }
    
    // MARK: - Functions
    @objc private func onTextDidChange() {
        guard let filter = chatSearchTextField.text else { return }
        filterChatList(filter)
    }
    
    private func addObservers() {
        observe(UITextField.textDidChangeNotification, #selector(onTextDidChange))
    }
    
    private func prepareUI() {
        chatSearchTextField.delegate = self
        cancelSearchButton.isHidden = true
    }
    
    private func prepareChatMenagerHandlers() {
        chatManager.chatListHandler = {
            self.updateChatList()
        }
    }
    
    private func setupTableView() {
        chatListTableView.delegate = self
        chatListTableView.dataSource = self
        chatListTableView.tableFooterView = UIView()
        chatListTableView.backgroundColor = UIColor.clear
        chatListTableView.register(cellType: ChatTableViewCell.self)
    }
    
    private func filterChatList(_ filter: String) {
        filteredChatList = filter.isEmpty ? chatManager.chatList : chatManager.chatList.filter { chatInfo in
            chatInfo.name.range(of: filter, options: .caseInsensitive, range: nil, locale: nil) != nil
        }
        chatListTableView.reloadData()
    }
    
    private func updateChatList() {
        filteredChatList = chatManager.chatList
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.filterChatList(self.chatSearchTextField.text ?? "")
            self.chatListTableView.reloadData()
        }
    }
    
    private func pushChatViewController(with index: Int) {
        let factory = InstantiateFromStoryboardFactory()
        let vc: ChatViewController = factory.instantiateFromStoryboard()
        vc.chat = filteredChatList[index]
        navigationController?.pushViewController(vc, animated: true)
    }
}

//MARK: - UITableViewDelegate & UITableViewDataSource
extension ChatListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredChatList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  tableView.dequeueReusableCell(with: ChatTableViewCell.self, for: indexPath)
        cell.configure(with: filteredChatList[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.defaultHeightForRow
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        pushChatViewController(with: indexPath.row)
    }
}

// MARK: - UITextFieldDelegate
extension ChatListViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        cancelSearchButton.isHidden = false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let filter = textField.text else {
            cancelSearchButton.isHidden = true
            return false
        }
        filterChatList(filter)
        textField.resignFirstResponder()
        return true
    }
}
