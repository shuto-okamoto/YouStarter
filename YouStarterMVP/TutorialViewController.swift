//
//  TutorialViewController.swift
//  YouStarterMVP
//
//  Tutorial flow for challenge onboarding
//

import UIKit

class TutorialViewController: UIViewController {
    
    private let messageLabel = UILabel()
    private let nextButton = UIButton(type: .system)
    private let skipButton = UIButton(type: .system)
    
    private var currentStep = 0
    private var tutorialSteps: [(message: String, action: TutorialAction)] {
        return [
            (LanguageManager.shared.localizedString(for: "tutorial_step1"), .goToWallet),
            (LanguageManager.shared.localizedString(for: "tutorial_step2"), .goToHome),
            (LanguageManager.shared.localizedString(for: "tutorial_step3"), .showMessage),
            (LanguageManager.shared.localizedString(for: "tutorial_step4"), .complete)
        ]
    }
    
    private enum TutorialAction {
        case goToWallet
        case goToHome
        case showMessage
        case complete
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showCurrentStep()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        // Message label setup
        messageLabel.textAlignment = .center
        messageLabel.textColor = .white
        messageLabel.font = UIFont.boldSystemFont(ofSize: 18)
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        
        // Next button setup
        nextButton.setTitle(LanguageManager.shared.localizedString(for: "next"), for: .normal)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.backgroundColor = .systemRed
        nextButton.layer.cornerRadius = 8
        nextButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        view.addSubview(nextButton)
        
        // Skip button setup
        skipButton.setTitle(LanguageManager.shared.localizedString(for: "skip"), for: .normal)
        skipButton.setTitleColor(.white, for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        view.addSubview(skipButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            nextButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 40),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 120),
            nextButton.heightAnchor.constraint(equalToConstant: 44),
            
            skipButton.topAnchor.constraint(equalTo: nextButton.bottomAnchor, constant: 20),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func showCurrentStep() {
        guard currentStep < tutorialSteps.count else {
            completeTutorial()
            return
        }
        
        let step = tutorialSteps[currentStep]
        messageLabel.text = step.message
        
        // Update button text based on action
        switch step.action {
        case .goToWallet:
            nextButton.setTitle(LanguageManager.shared.localizedString(for: "tutorial_go_to_wallet"), for: .normal)
        case .goToHome:
            nextButton.setTitle(LanguageManager.shared.localizedString(for: "tutorial_go_to_home"), for: .normal)
        case .showMessage, .complete:
            nextButton.setTitle(LanguageManager.shared.localizedString(for: "next"), for: .normal)
        }
        
        if currentStep == tutorialSteps.count - 1 {
            nextButton.setTitle(LanguageManager.shared.localizedString(for: "start"), for: .normal)
        }
    }
    
    @objc private func nextButtonTapped() {
        let step = tutorialSteps[currentStep]
        
        switch step.action {
        case .goToWallet:
            navigateToWallet()
        case .goToHome:
            navigateToHome()
        case .showMessage:
            currentStep += 1
            showCurrentStep()
        case .complete:
            completeTutorial()
        }
    }
    
    @objc private func skipButtonTapped() {
        completeTutorial()
    }
    
    private func navigateToWallet() {
        dismiss(animated: true) {
            if let tabBarController = self.presentingViewController as? UITabBarController {
                tabBarController.selectedIndex = 3 // Wallet tab
            }
        }
        currentStep += 1
    }
    
    private func navigateToHome() {
        dismiss(animated: true) {
            if let tabBarController = self.presentingViewController as? UITabBarController {
                tabBarController.selectedIndex = 0 // Home tab
            }
        }
        currentStep += 1
    }
    
    private func completeTutorial() {
        // Mark tutorial as completed
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
        
        dismiss(animated: true) {
            // Navigate to home tab to start challenge
            if let tabBarController = self.presentingViewController as? UITabBarController {
                tabBarController.selectedIndex = 0 // Home tab
            }
        }
    }
}