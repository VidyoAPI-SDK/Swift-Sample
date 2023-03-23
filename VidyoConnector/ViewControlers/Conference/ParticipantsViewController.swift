//
//  ParticipantsViewController.swift
//  VidyoConnector-iOS
//
//  Created by Marta Korol on 05.07.2021.
//

import UIKit

class ParticipantsViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var closeBarButton: UIBarButtonItem!
    @IBOutlet weak var participantsTableView: UITableView!
    
    // MARK: - Const & vars
    private var participants = [Participant]()
    var participantManager: ParticipantsManager?
    var pinnedParticipantFromConference: String?
    var passPinnedParticipantHandler: ((String?) -> ())?
    var pinnedParticipantsId: String? {
        return participants.filter { $0.isPinned }.map { $0.id }.first
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        addObservers()
        setupTableView()
        configureParticipantData()
        navigationBar.topItem?.title = String(format: Constants.ParticipantsScreen.title, "\(participants.count)")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeObservers()
    }

    // MARK: - IBActions
    @IBAction func closeBarButtonPressed(_ sender: UIBarButtonItem) {
        passPinnedParticipantHandler?(pinnedParticipantsId)
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Functions
    @objc private func onParticipantJoinedConference(_ notification: Notification) {
        guard let participant = notification.userInfo?[UserInfoKey.participant] as? VCParticipant else { return }
        participants.append(Participant(participant))
        participants = participants.sorted { $0.name.lowercased() < $1.name.lowercased() }
        updateUI(onStateChanged: false)
    }
    
    @objc private func onParticipantLeftConference(_ notification: Notification) {
        guard let participant = notification.userInfo?[UserInfoKey.participant] as? VCParticipant else { return }
        participants = participants.filter { $0.id != participant.getId()}
        updateUI(onStateChanged: false)
    }
        
    func addObservers() {
        observe(.participantJoinedConference, #selector(onParticipantJoinedConference))
        observe(.participantLeftConference, #selector(onParticipantLeftConference))
    }

    private func setupTableView() {
        participantsTableView.delegate = self
        participantsTableView.dataSource = self
        participantsTableView.tableFooterView = UIView()
        participantsTableView.backgroundColor = UIColor.clear
        participantsTableView.register(cellType: ParticipantTableViewCell.self)
    }
    
    private func configureParticipantData() {
        participantManager?.participants.forEach {
            participants.append(Participant($0))
        }
        participants = participants.sorted { $0.name.lowercased() < $1.name.lowercased() }.map {
            if $0.id == pinnedParticipantFromConference {
                var current = $0
                current.isPinned = true
                return current
            }
            return $0
        }
        setupRemoteCallbackHandlers()
        participantManager?.registerRemoteDevices()
    }
    
    private func updateUI(onStateChanged: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.participantsTableView.reloadData()
            guard !onStateChanged else { return }
            let title = String(format: Constants.ParticipantsScreen.title, "\(self.participants.count)")
            self.navigationBar.topItem?.title = title
        }
    }
    
    private func getParticipant(forRow index: Int) -> Participant? {
        guard index < participants.count else { return nil }
        if participants[index].isLocal {
            participants[index].isMicMuted = PreferencesManager.shared.getCurrentState(of: .mic)
            participants[index].isCameraMuted = PreferencesManager.shared.getCurrentState(of: .camera)
        }
        return participants[index]
    }
    
    private func setupRemoteCallbackHandlers() {
        // Remote micro handlers
        participantManager?.onParticipantMicrophoneStateUpdatedHandler = { [weak self] (participantID, state) in
            guard let self = self else { return }
            guard let index =  self.participants.firstIndex(where: {$0.id == participantID}) else { return }
            self.participants[index].isMicMuted = state
            self.updateUI(onStateChanged: true)
        }
        // Remote camera handlers
        participantManager?.onParticipantCameraAddedHandler = { [weak self] (participantID) in
            guard let self = self else { return }
            guard let index =  self.participants.firstIndex(where: {$0.id == participantID}) else { return }
            self.participants[index].isCameraMuted = false
            self.updateUI(onStateChanged: true)
        }
        participantManager?.onParticipantCameraStateUpdatedHandler = { [weak self] (participantID, isControllable) in
            guard let self = self else { return }
            guard let index =  self.participants.firstIndex(where: {$0.id == participantID}) else { return }
            self.participants[index].isCameraControllable = isControllable
            self.updateUI(onStateChanged: true)
        }
        participantManager?.onParticipantCameraRemovedHandler = { [weak self] (participantID) in
            guard let self = self else { return }
            self.remoteCameraMuted(participantID)
            self.updateUI(onStateChanged: true)
        }
    }
    
    private func remoteCameraMuted(_ participantID: String) {
        guard let index =  participants.firstIndex(where: {$0.id == participantID}) else { return }
        participants[index].isCameraMuted = true
        participants[index].isCameraControllable = false
        participants[index].isPinned = false
    }
    
    private func handleParticipantPin(withIndex index: Int) {
        guard participantManager!.pinPartisipant(participants[index].id, pin: !participants[index].isPinned) else { return }
        
        if !participants[index].isPinned {
            participants = participants.map {
                var option = $0
                guard option.isPinned == true else { return option }
                option.isPinned = false
                return option
            }
        }
        
        participants[index].isPinned = !participants[index].isPinned
        participantsTableView.reloadData()
    }
}

//MARK: - UITableViewDelegate & UITableViewDataSource
extension ParticipantsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        participants.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let participant = getParticipant(forRow: indexPath.row) else {
            return UITableViewCell()
        }
        let cell =  tableView.dequeueReusableCell(with: ParticipantTableViewCell.self, for: indexPath)
        cell.pinParticipantHandler = { [weak self] in
            guard let self = self else { return }
            self.handleParticipantPin(withIndex: indexPath.row)
        }
        cell.configure(with: participant)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Constants.ParticipantsScreen.heightForTableViewRow
    }
}
