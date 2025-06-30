// HomeViewController.swift

import UIKit

class HomeViewController: UIViewController {
    // MARK: - UI Elements
    private let startChallengeButton = UIButton(type: .system)
    private let deadlineLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "YouStarter"
        view.backgroundColor = .systemBackground
        setupUI()
        updateUI()

        NotificationCenter.default.addObserver(self, selector: #selector(handlePurchaseSuccess), name: .iapPurchaseSuccess, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: .iapPurchaseFailure, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    // MARK: - UI Setup
    private func setupUI() {
        // …（省略）…
    }

    // MARK: - UI Update
    @objc private func updateUI() {
        if let challenge = ChallengeManager.shared.currentChallenge, challenge.isActive {
            startChallengeButton.isHidden = true
            deadlineLabel.isHidden = false
            if let deadline = UserDefaults.standard.object(forKey: "nextPlayDeadline") as? Date {
                let formatter = DateFormatter()
                if LanguageManager.shared.currentLanguage == .japanese {
                    formatter.dateFormat = "M月d日 H時m分"
                } else {
                    formatter.dateFormat = "MMM d, h:mm a"
                }
                deadlineLabel.text = String(format: LanguageManager.shared.localizedString(for: "deadline_format"), formatter.string(from: deadline))
            } else {
                deadlineLabel.text = LanguageManager.shared.localizedString(for: "no_deadline_set")
            }
        } else {
            startChallengeButton.isHidden = false
            deadlineLabel.isHidden = true
        }
        // 🔥 checkDeadline() の呼び出しを削除しました
    }

    // MARK: - Actions
    @objc private func startChallengeTapped() {
        // …（省略）…
    }

    // MARK: - Deadline Logic
    private func checkDeadline() {
        // このメソッド自体は残しておいても問題ありませんが、
        // updateUI() から呼ばれなくなります
        let defaults = UserDefaults.standard
        guard let deadline = defaults.object(forKey: "nextPlayDeadline") as? Date else { return }
        if Date() > deadline {
            showContinueAlert()
        }
    }

    private func showContinueAlert() {
        // …（省略）…
    }

    private func purchaseContinue() {
        // …（省略）…
    }

    @objc private func handlePurchaseSuccess() {
        // …（省略）…
    }
}
