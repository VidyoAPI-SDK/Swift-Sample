//
//  ChatViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 12.08.2021.
//

import UIKit

class ChatViewController: UIViewController {

    // MARK: - IBOutlets
    // Navigation Bar View
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var avatarView: UIView!
    @IBOutlet weak var chatTitleLabel: UILabel!
    // Chat Table View
    @IBOutlet weak var chatTableView: UITableView!
    // Message Input View
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var leftConferenceMessage: UILabel!
    @IBOutlet weak var messageInputContainerView: UIView!
    // Constraint
    @IBOutlet weak var messageInputBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Const & vars
    private let avatar = AvatarView.loadFromNib()
    private var tableHeaderView = UIView(frame: .zero)
    private let groupChatTitleFormat = "Group Chat (%@ Participant%@)"
    
    var chat = Chat()

    var rowsHeight: CGFloat {
        var rowsHeight: CGFloat = 0
        for index in 0..<chat.messages.count {
            guard rowsHeight < chatTableView.frame.size.height else { return 0 }
            let indexPath = IndexPath(row: index, section: 0)
            rowsHeight += chatTableView.rectForRow(at: indexPath).height
        }
        return rowsHeight
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addObservers()
        addTapGestureRecognizerForKeyboardHiding()
        
        setupNavigationBar()
        setupTableView()
        setupMessageInput()
        prepareChatMenagerHandlers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToBottom()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
    }
    
    // MARK: - IBActions
    @IBAction func backButtonPressed(_ sender: UIButton) {
        chat.newMessageCount = 0
        chatManager.updateChat(chat)
        chatManager.chatEventsHandler = nil
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func sendButtonPressed(_ sender: UIButton) {
        appendNewMessage()
    }
    
    // MARK: - Functions
    @objc private func onKeyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        if let keyboardFrame: NSValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let bottomPadding = view.safeAreaInsets.bottom
            let keyboardHeight = keyboardFrame.cgRectValue.height - bottomPadding
            messageInputBottomConstraint.constant = keyboardHeight
            updateConstraints { _ in
                self.scrollToBottom()
            }
        }
    }
    
    @objc private func onKeyboardWillHide() {
        messageInputBottomConstraint.constant = 0
        updateConstraints{ _ in
            self.sizeHeaderViewToFit()
        }
    }
    
    private func addObservers() {
        observe(UIResponder.keyboardWillShowNotification, #selector(onKeyboardWillShow))
        observe(UIResponder.keyboardWillHideNotification, #selector(onKeyboardWillHide))
    }
        
    private func addAvatar() {
        avatarView.addSubview(avatar)
        avatarView.backgroundColor = .clear
        avatar.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor).isActive = true
        avatar.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor).isActive = true
    }
    
    private func setupNavigationBar() {
        addAvatar()
        updateChatTitle()
        
        guard !chat.isGroupChat else {
            avatar.showGroupChat()
            return
        }
        avatar.setIntitials(chat.avatarInitials)
    }
    
    private func setupTableView() {
        chatTableView.delegate = self
        chatTableView.dataSource = self
        chatTableView.register(cellType: SentMessageTableViewCell.self)
        chatTableView.register(cellType: ReceivedMessageTableViewCell.self)
        chatTableView.register(cellType: ChatNotificationTableViewCell.self)
        // HeaderView
        tableHeaderView.frame = CGRect(
            x: 0, y: 0,
            width: chatTableView.frame.size.width,
            height: chatTableView.frame.size.height
        )
        chatTableView.tableHeaderView = tableHeaderView
        chatTableView.tableHeaderView?.isUserInteractionEnabled = false
    }
    
    private func setupMessageInput() {
        messageTextField.delegate = self
        
        messageTextField.leftView = Constants.Chat.textFieldPaddingView
        messageTextField.rightView = Constants.Chat.textFieldPaddingView
        messageTextField.leftViewMode = .always
        messageTextField.rightViewMode = .always
        
        if !chat.isActive {
            messageTextField.isHidden = true
            sendButton.isHidden = true
            leftConferenceMessage.isHidden = false
            leftConferenceMessage.textColor = .white
            leftConferenceMessage.text = String(format: Constants.Chat.participantLeftMessage, "\(chat.name)")
        }
    }
    
    private func updateChatTitle() {
        guard chat.isGroupChat else {
            chatTitleLabel.text = chat.name
            return
        }
        updateGroupChatTitle()
    }
    
    private func updateGroupChatTitle() {
        let plural = chatManager.participantsNumber > 1 ? "s" : ""
        let arguments = [String(chatManager.participantsNumber), plural]
        chatTitleLabel.text = String(format: groupChatTitleFormat, arguments: arguments)
    }
    
    private func updatePrivateChatUI(isActive: Bool) {
        chat.isActive = isActive
        DispatchQueue.main.async {
            self.messageTextField.isHidden = !isActive
            self.sendButton.isHidden = !isActive
            self.leftConferenceMessage.isHidden = isActive
            guard !isActive else { return }
            self.leftConferenceMessage.textColor = .white
            self.leftConferenceMessage.text = String(format: Constants.Chat.participantLeftMessage, "\(self.chat.name)")
        }
    }
    
    private func updateConstraints(completion: ((Bool) -> (Void))? = nil) {
        UIView.animate(
            withDuration: 0,
            delay: 0,
            options: .curveEaseOut,
            animations: { self.view.layoutIfNeeded() },
            completion: completion
        )
    }
    
    private func scrollToBottom(isAnimated:Bool = true) {
        sizeHeaderViewToFit()
        guard !chat.messages.isEmpty else { return }
        let indexPath = IndexPath(row: chat.messages.count - 1, section: 0)
        chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: isAnimated)
    }
    
    private func sizeHeaderViewToFit() {
        guard !chat.messages.isEmpty else { return }
        guard chatTableView.frame.size.height > rowsHeight else {
            tableHeaderView.frame = .zero
            return
        }
        let height = rowsHeight == 0 ? 0 : chatTableView.frame.size.height - rowsHeight
        let width = chatTableView.frame.size.width
        tableHeaderView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        chatTableView.tableHeaderView = tableHeaderView
    }
    
    private func sendMessage(_ message: String) -> Bool {
        var sent = false
        if chat.isGroupChat {
            sent = chatManager.sendGroupMessage(body: message)
            guard sent else {
                log.error("Group message sending failed.")
                return sent
            }
        } else {
            guard let participant = chat.participant else { return sent }
            sent = chatManager.sendPrivateMessage(message, to: participant)
            guard sent else {
                log.error("Private message sending failed.")
                return sent
            }
        }
        return sent
    }
    
    private func appendNewMessage() {
        guard let message = messageTextField.text, !message.isEmpty else { return }
        guard sendMessage(message) else { return }
        // Update data
        chat.messages.append(Message(text: message, date: Date()))
        chatManager.updateChat(chat)
        //Update UI
        messageTextField.text = nil
        chatTableView.reloadData()
        scrollToBottom()
    }
    
    private func appendNewReceivedMessage(_ message: MessageProtocol) {
        chat.messages.append(message)
        chatManager.updateChat(chat)
        chatTableView.reloadData()
        scrollToBottom()
    }
    
    private func prepareChatMenagerHandlers() {
        chatManager.chatEventsHandler = { [weak self] message in
            guard let self = self else { return }
            self.handleGroupChatEvents(message)
            if let notification = message as? ChatNotification {
                self.participantStatusChangedDuringPrivateChatting(notification)
            }
        }
        chatManager.privateChatEventsHandler = { [weak self] message in
            guard let self = self else { return }
            if let message = message as? Message {
                guard self.chat.id == message.senderID else { return }
                DispatchQueue.main.async {
                    self.appendNewReceivedMessage(message)
                }
            }
        }
    }
    
    private func handleGroupChatEvents(_ message: MessageProtocol) {
        guard chat.isGroupChat else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.appendNewReceivedMessage(message)
            if message is ChatNotification {
                self.updateGroupChatTitle()
            }
        }
    }
    
    private func participantStatusChangedDuringPrivateChatting(_ notification: ChatNotification) {
        guard notification.participantID == chat.id else { return }
        switch notification.event {
        case .leftConference:
            updatePrivateChatUI(isActive: false)
        case .joinedConference:
            updatePrivateChatUI(isActive: true)
        default: return
        }
    }
}

//MARK: - UITableViewDelegate & UITableViewDataSource
extension ChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        chat.messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var messageCell: MessageTableViewCellProtocol?

        switch chat.messages[indexPath.row].type {
        case .message:
            guard let message = chat.messages[indexPath.row] as? Message else {
                return UITableViewCell()
            }
            let sentCell = tableView.dequeueReusableCell(with: SentMessageTableViewCell.self, for: indexPath)
            let receivedCell = tableView.dequeueReusableCell(with: ReceivedMessageTableViewCell.self, for: indexPath)
            messageCell = message.isSender ? receivedCell : sentCell
            
        case .notification:
            messageCell = tableView.dequeueReusableCell(with: ChatNotificationTableViewCell.self, for: indexPath)
        }

        guard let cell = messageCell else { return UITableViewCell() }
        cell.configure(with: chat.messages[indexPath.row])
        return cell
    }
}

// MARK: - UITextFieldDelegate
extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        appendNewMessage()
        return true
    }
}
