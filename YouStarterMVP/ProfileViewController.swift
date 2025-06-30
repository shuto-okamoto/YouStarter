import UIKit

/// IAP復元完了の通知名
extension Notification.Name {
    static let iapRestored = Notification.Name("iapRestored")
}


final class ProfileViewController: UIViewController, VideoManagerDelegate {
    // MARK: UI Elements
    private let statusLabel    = UILabel()
    private lazy var challengeStatusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private lazy var remainingDaysLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private lazy var continueChallengeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(LanguageManager.shared.localizedString(for: "continue_challenge_button"), for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(continueChallengeTapped), for: .touchUpInside)
        return button
    }()
    private lazy var startNewChallengeButton: UIButton = { // New button for starting a new challenge
        let button = UIButton(type: .system)
        button.setTitle(LanguageManager.shared.localizedString(for: "yes"), for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(startNewChallengeTapped), for: .touchUpInside)
        return button
    }()
    private lazy var challengeProgressView: ChallengeProgressView = { // Add this line
        let view = ChallengeProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()


    // Get sayings from FileBasedConfigManager
    private func getSaying(for index: Int) -> String {
        let sayings = FileBasedConfigManager.shared.loadSayings()
        guard !sayings.isEmpty, index < sayings.count else {
            return FileBasedConfigManager.shared.getCurrentSaying()
        }
        
        let currentLanguage = LanguageManager.shared.currentLanguage
        let selectedSaying = sayings[index]
        return currentLanguage == .japanese ? selectedSaying.japanese : selectedSaying.english
    }
    
    private var totalSayings: Int {
        return FileBasedConfigManager.shared.loadSayings().count
    }


    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "tab_challenge")
        view.backgroundColor = .systemBackground

        // Set up VideoManager delegate (fallback for other tabs)
        if VideoManager.shared.delegate == nil {
            VideoManager.shared.delegate = self
        }

        setupUI()
        updateUI()
        
        // チャレンジ状態変更の通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateUI),
            name: .challengeStateChanged,
            object: nil
        )
        
        // 言語変更時にタイトルを更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLocalization),
            name: NSNotification.Name("LanguageChanged"),
            object: nil
        )
        
        // チャレンジUI完全リセット通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChallengeUIReset),
            name: NSNotification.Name("ChallengeUIReset"),
            object: nil
        )
    }
    
    @objc private func updateLocalization() {
        title = LanguageManager.shared.localizedString(for: "tab_challenge")
    }
    
    @objc private func handleChallengeUIReset() {
        print("ProfileViewController: チャレンジUI完全リセット通知を受信しました")
        
        // UIを強制的にチャレンジ前の状態にリセット
        DispatchQueue.main.async {
            self.resetToPreChallengeState()
            self.updateUI()
        }
    }
    
    /// UIをチャレンジ前の状態に強制リセット
    private func resetToPreChallengeState() {
        // チャレンジ関連のすべてのUI要素を初期状態に戻す
        challengeStatusLabel.isHidden = true
        challengeStatusLabel.text = ""
        
        statusLabel.isHidden = false
        statusLabel.text = LanguageManager.shared.localizedString(for: "show_your_resolve")
        
        challengeProgressView.isHidden = true
        challengeProgressView.completedSegments = 0
        challengeProgressView.sayingText = ""
        
        remainingDaysLabel.isHidden = true
        remainingDaysLabel.text = ""
        
        continueChallengeButton.isHidden = true
        startNewChallengeButton.isHidden = true
        
        print("ProfileViewController: UIをチャレンジ前の状態にリセットしました")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // プロフィール画面が表示されるたびにUIを更新
        updateUI()
        
        // Trigger animation when tab is selected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.challengeProgressView.animateProgress()
        }
    }


    // MARK: UI Setup
    private func setupUI() {
        // Add all subviews first
        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false


        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isUserInteractionEnabled = true
        
        // Add tap gesture to status label for tutorial
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(statusLabelTapped))
        statusLabel.addGestureRecognizer(tapGesture)


        // Position statusLabel at the center of the screen (for pre-purchase text)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        setupChallengeUI() // Call setupChallengeUI after statusLabel is set up
    }


    private func setupChallengeUI() {
        // Initialize and add all challenge-related subviews
        challengeProgressView = ChallengeProgressView()
        challengeProgressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(challengeProgressView)


        challengeStatusLabel = UILabel()
        challengeStatusLabel.textAlignment = .center
        challengeStatusLabel.textColor = .secondaryLabel
        challengeStatusLabel.numberOfLines = 0
        challengeStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(challengeStatusLabel)

        remainingDaysLabel = UILabel()
        remainingDaysLabel.textAlignment = .center
        remainingDaysLabel.textColor = .secondaryLabel
        remainingDaysLabel.numberOfLines = 0
        remainingDaysLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(remainingDaysLabel)


        continueChallengeButton = UIButton(type: .system)
        continueChallengeButton.setTitle(LanguageManager.shared.localizedString(for: "continue_challenge_button"), for: .normal)
        continueChallengeButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        continueChallengeButton.translatesAutoresizingMaskIntoConstraints = false
        continueChallengeButton.addTarget(self, action: #selector(continueChallengeTapped), for: .touchUpInside)
        view.addSubview(continueChallengeButton)




        // Start New Challenge Button
        startNewChallengeButton = UIButton(type: .system)
        startNewChallengeButton.setTitle(LanguageManager.shared.localizedString(for: "yes"), for: .normal)
        startNewChallengeButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        startNewChallengeButton.translatesAutoresizingMaskIntoConstraints = false
        startNewChallengeButton.addTarget(self, action: #selector(startNewChallengeTapped), for: .touchUpInside)
        view.addSubview(startNewChallengeButton)


        // Activate constraints for all challenge-related UI elements
        NSLayoutConstraint.activate([
            // Position challengeStatusLabel at the top of the screen
            challengeStatusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            challengeStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            challengeStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Center the progress view independently in the screen
            challengeProgressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            challengeProgressView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            challengeProgressView.widthAnchor.constraint(equalToConstant: 200),
            challengeProgressView.heightAnchor.constraint(equalToConstant: 200),

            // Position remainingDaysLabel below the progress view (under sayings)
            remainingDaysLabel.topAnchor.constraint(equalTo: challengeProgressView.bottomAnchor, constant: 20),
            remainingDaysLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            remainingDaysLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Position buttons below the remaining days label
            continueChallengeButton.topAnchor.constraint(equalTo: remainingDaysLabel.bottomAnchor, constant: 30),
            continueChallengeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            startNewChallengeButton.topAnchor.constraint(equalTo: continueChallengeButton.bottomAnchor, constant: 20),
            startNewChallengeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }


    // MARK: - UI Update
    @objc private func updateUI() {
        print("--- ProfileViewController: updateUI called ---")
        if let challenge = ChallengeManager.shared.currentChallenge {
            print("ProfileViewController: Challenge exists. isActive: \(challenge.isActive), isFailed: \(challenge.isFailed), IsCompleted: \(challenge.isCompleted)")
            challengeProgressView.isHidden = false
            challengeProgressView.totalSegments = 30
            startNewChallengeButton.isHidden = true // デフォルトで非表示に


            if challenge.isActive {
                // Use watched dates count instead of elapsed days for accurate progress
                let watchedDaysCount = ChallengeManager.shared.getCompletedDays()
                challengeProgressView.completedSegments = min(watchedDaysCount, 30)
                
                // Also calculate elapsed days for sayings
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day], from: challenge.startDate, to: Date())
                let elapsedDays = components.day ?? 0

                // Display sayings based on progress days
                let dayIndex = min(watchedDaysCount, totalSayings - 1)
                challengeProgressView.sayingText = getSaying(for: dayIndex)

                let remainingDays = Calendar.current.dateComponents([.day], from: Date(), to: challenge.endDate).day ?? 0
                
                // Set challenge status at the top
                challengeStatusLabel.text = LanguageManager.shared.localizedString(for: "challenge_status_in_progress")
                challengeStatusLabel.isHidden = false
                
                // Set remaining days below the progress view
                remainingDaysLabel.text = String(format: LanguageManager.shared.localizedString(for: "remaining_days_format"), remainingDays)
                remainingDaysLabel.isHidden = false
                
                // Hide pre-purchase text
                statusLabel.isHidden = true
                continueChallengeButton.isHidden = true // アクティブな場合は非表示

            } else if challenge.isFailed {
                // Set challenge status at the top
                challengeStatusLabel.text = LanguageManager.shared.localizedString(for: "challenge_status_failed")
                challengeStatusLabel.isHidden = false
                
                // Hide pre-purchase text and remaining days
                statusLabel.isHidden = true
                remainingDaysLabel.isHidden = true
                
                continueChallengeButton.isHidden = false // 失敗した場合のみ表示
                continueChallengeButton.setTitle(String(format: LanguageManager.shared.localizedString(for: "continue_challenge_button"), challenge.cost), for: .normal)
                challengeProgressView.completedSegments = 0 // Reset progress on failure
                challengeProgressView.sayingText = LanguageManager.shared.localizedString(for: "sayings_failure")

                // 失敗日時が今日の23:59を過ぎていたらコンティニューボタンを非表示
                if let failedDate = challenge.isFailedDate {
                    let calendar = Calendar.current
                    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: failedDate)!
                    if Date() > endOfDay {
                        challengeStatusLabel.text = LanguageManager.shared.localizedString(for: "challenge_continue_failed_today")
                        continueChallengeButton.isHidden = true
                    } else {
                        challengeStatusLabel.text = LanguageManager.shared.localizedString(for: "challenge_continue_failed_question")
                    }
                }
            } else if challenge.isCompleted {
                // Set challenge status at the top
                challengeStatusLabel.text = LanguageManager.shared.localizedString(for: "challenge_status_success")
                challengeStatusLabel.isHidden = false
                
                // Hide pre-purchase text and remaining days
                statusLabel.isHidden = true
                remainingDaysLabel.isHidden = true
                
                continueChallengeButton.isHidden = true // 完了した場合は非表示
                challengeProgressView.completedSegments = 30 // Full progress on completion
                challengeProgressView.sayingText = LanguageManager.shared.localizedString(for: "sayings_success")

                startNewChallengeButton.isHidden = false // 完了した場合は「はい」ボタンを表示
            }
        } else {
            // Show pre-purchase text at center
            statusLabel.text = LanguageManager.shared.localizedString(for: "show_your_resolve")
            statusLabel.textColor = .systemBlue // Make text blue to indicate it's tappable
            statusLabel.isHidden = false
            
            // Hide challenge-related UI
            challengeStatusLabel.isHidden = true
            remainingDaysLabel.isHidden = true
            continueChallengeButton.isHidden = true
            challengeProgressView.isHidden = true
            challengeProgressView.sayingText = ""
            
            startNewChallengeButton.isHidden = true // チャレンジがない場合は「はい」ボタンを非表示
        }
    }




    @objc private func continueChallengeTapped() {
        guard let challenge = ChallengeManager.shared.currentChallenge else {
            return
        }
        let alert = UIAlertController(title: LanguageManager.shared.localizedString(for: "continue_challenge_confirmation"), message:
String(format: LanguageManager.shared.localizedString(for: "continue_challenge_confirmation_message"), challenge.cost), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "continue_text"), style: .default, handler: { _ in
            if ChallengeManager.shared.continueChallenge() {
                self.updateUI()
            } else {
                let errorAlert = UIAlertController(title: LanguageManager.shared.localizedString(for: "challenge_continue_error"), message:
LanguageManager.shared.localizedString(for: "challenge_continue_error_message"), preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
                self.present(errorAlert, animated: true)
            }
        }))
        present(alert, animated: true)
    }


    @objc private func startNewChallengeTapped() {
        let alert = UIAlertController(title: LanguageManager.shared.localizedString(for: "challenge_start_new"), message: LanguageManager.shared.localizedString(for: "challenge_start_new_message"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default, handler: { _ in
            // 新しいチャレンジ開始のため、現在のチャレンジ状態を適切にリセット
            ChallengeManager.shared.resetChallenge()
            
            // UIを更新してチャレンジ前の状態に戻す
            self.updateUI()
            
            // ホーム画面に遷移
            if let tabBarController = self.tabBarController {
                tabBarController.selectedIndex = 0
            }
        }))
        present(alert, animated: true)
    }
    
    // MARK: - VideoManagerDelegate
    func videoManager(_ manager: VideoManager, didUpdateMinimizedState isMinimized: Bool) {
        // No specific UI updates needed in Profile tab
    }
    
    func videoManager(_ manager: VideoManager, didCompleteVideo duration: TimeInterval) {
        // Video completion handling will be done by ViewController
    }
    
    func videoManager(_ manager: VideoManager, didPlayFor5Minutes: Void) {
        // 5-minute playback handling will be done by ViewController
    }
    
    func videoManager(_ manager: VideoManager, shouldSwitchToHomeTab: Void) {
        // Switch to Home tab when video is maximized
        DispatchQueue.main.async {
            self.tabBarController?.selectedIndex = 0
        }
    }
    
    func videoManager(_ manager: VideoManager, didStopVideo: Void) {
        // No specific action needed in Profile tab
    }
    
    // MARK: - Tutorial
    @objc private func statusLabelTapped() {
        // Only show tutorial if no active challenge
        guard ChallengeManager.shared.currentChallenge == nil else { return }
        
        let tutorialVC = TutorialViewController()
        tutorialVC.modalPresentationStyle = .overFullScreen
        present(tutorialVC, animated: true)
    }
}
