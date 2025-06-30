// MoneyBagViewController.swift
// YouStarterMVP

import UIKit

final class MoneyBagViewController: UIViewController, VideoManagerDelegate {

    private let moneyBagView = MoneyBagView()
    private let inputButton = UIButton(type: .system)
    private let remainingDaysLabel = UILabel()

    private let currentAmountKey = "moneyBagCurrentAmount_v2"

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "tab_results")
        view.backgroundColor = .systemBackground

        // Set up VideoManager delegate (fallback for other tabs)
        if VideoManager.shared.delegate == nil {
            VideoManager.shared.delegate = self
        }

        setupUI()
        loadAmounts()
        updateMoneyBagView()
        
        // 言語変更時にタイトルを更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLocalization),
            name: NSNotification.Name("LanguageChanged"),
            object: nil
        )
    }
    
    @objc private func updateLocalization() {
        title = LanguageManager.shared.localizedString(for: "tab_results")
        inputButton.setTitle(LanguageManager.shared.localizedString(for: "input_amount"), for: .normal)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateMoneyBagView()
    }

    private func setupUI() {
        moneyBagView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(moneyBagView)

        inputButton.setTitle(LanguageManager.shared.localizedString(for: "input_amount"), for: .normal)
        inputButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        inputButton.translatesAutoresizingMaskIntoConstraints = false
        inputButton.addTarget(self, action: #selector(inputAmountTapped), for: .touchUpInside)
        view.addSubview(inputButton)

        remainingDaysLabel.textAlignment = .center
        remainingDaysLabel.font = UIFont.preferredFont(forTextStyle: .body)
        remainingDaysLabel.translatesAutoresizingMaskIntoConstraints = false
        remainingDaysLabel.isUserInteractionEnabled = true
        
        // Add tap gesture to remaining days label for tutorial
        let tutorialTapGesture = UITapGestureRecognizer(target: self, action: #selector(remainingDaysLabelTapped))
        remainingDaysLabel.addGestureRecognizer(tutorialTapGesture)
        
        view.addSubview(remainingDaysLabel)

        NSLayoutConstraint.activate([
            moneyBagView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            moneyBagView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            moneyBagView.widthAnchor.constraint(equalToConstant: 200),
            moneyBagView.heightAnchor.constraint(equalToConstant: 250),

            inputButton.topAnchor.constraint(equalTo: moneyBagView.bottomAnchor, constant: 40),
            inputButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            // Center remainingDaysLabel in the middle of the screen when no challenge
            remainingDaysLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            remainingDaysLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            remainingDaysLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            remainingDaysLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        // Add tap gesture to moneyBagView for input
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(inputAmountTapped))
        moneyBagView.addGestureRecognizer(tapGesture)
        moneyBagView.isUserInteractionEnabled = true
    }

    private func loadAmounts() {
        moneyBagView.currentAmount = UserDefaults.standard.integer(forKey: currentAmountKey)
    }

    private func saveAmounts() {
        UserDefaults.standard.set(moneyBagView.currentAmount, forKey: currentAmountKey)
    }

    private func updateMoneyBagView() {
        moneyBagView.currentAmount = UserDefaults.standard.integer(forKey: currentAmountKey)

        if let challenge = ChallengeManager.shared.currentChallenge, challenge.isActive {
            // Show challenge-related UI
            moneyBagView.targetAmount = challenge.targetMoneyAmount
            let calendar = Calendar.current
            let remainingDays = calendar.dateComponents([.day], from: Date(), to: challenge.endDate).day ?? 0
            remainingDaysLabel.text = String(format: LanguageManager.shared.localizedString(for: "remaining_days_format"), remainingDays)
            remainingDaysLabel.textColor = .label // Normal text color
            remainingDaysLabel.isHidden = false
            inputButton.isHidden = false
            moneyBagView.isHidden = false
        } else {
            // Hide challenge UI, show only the blue tappable text
            remainingDaysLabel.text = LanguageManager.shared.localizedString(for: "show_your_resolve")
            remainingDaysLabel.textColor = .systemBlue // Blue to indicate it's tappable
            remainingDaysLabel.isHidden = false
            inputButton.isHidden = true
            moneyBagView.isHidden = true // Hide the money bag view completely
        }
        moneyBagView.setNeedsDisplay()
    }

    @objc private func inputAmountTapped() {
        let alert = UIAlertController(title: LanguageManager.shared.localizedString(for: "input_amount_alert_title"), message: LanguageManager.shared.localizedString(for: "input_amount_alert_message"), preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = LanguageManager.shared.localizedString(for: "amount_placeholder")
            textField.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "add"), style: .default, handler: { _ in
            if let text = alert.textFields?.first?.text, let amount = Int(text) {
                self.moneyBagView.currentAmount += amount
                self.saveAmounts()
                self.updateMoneyBagView()
            }
        }))
        present(alert, animated: true)
    }

    @objc private func setTargetAmountTapped() {
        // This button is now removed as target amount is set via challenge
    }
    
    // MARK: - VideoManagerDelegate
    func videoManager(_ manager: VideoManager, didUpdateMinimizedState isMinimized: Bool) {
        // No specific UI updates needed in MoneyBag tab
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
        // No specific action needed in MoneyBag tab
    }
    
    // MARK: - Tutorial
    @objc private func remainingDaysLabelTapped() {
        // Only show tutorial if no active challenge and showing the "稼ぐ覚悟を見せてくれ。" message
        guard ChallengeManager.shared.currentChallenge == nil,
              remainingDaysLabel.text == LanguageManager.shared.localizedString(for: "show_your_resolve") else { return }
        
        let tutorialVC = TutorialViewController()
        tutorialVC.modalPresentationStyle = .overFullScreen
        present(tutorialVC, animated: true)
    }
}
