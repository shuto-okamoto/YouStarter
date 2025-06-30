//
//  PlanStatusViewController.swift
//  YouStarterMVP
//
//  Created by You on 2025/06/28.
//

import UIKit

class PlanStatusViewController: UIViewController {

    // MARK: - UI Elements

    private let streakLabel   = UILabel()
    private let progressView  = UIProgressView(progressViewStyle: .default)
    private let completeButton = UIButton(type: .system)

    // MARK: - Data

    private var plan: GuaranteePlan?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "plan_status_title")
        view.backgroundColor = .systemBackground

        setupUI()
        fetchPlanStatus()
    }

    private func setupUI() {
        // Use preferredFont for title2 style
        streakLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        streakLabel.textAlignment = .center

        progressView.translatesAutoresizingMaskIntoConstraints = false

        completeButton.setTitle(LanguageManager.shared.localizedString(for: "mission_complete_today"), for: .normal)
        completeButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        completeButton.translatesAutoresizingMaskIntoConstraints = false
        completeButton.addTarget(self, action: #selector(reportCompletion), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [streakLabel, progressView, completeButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Networking

    private func fetchPlanStatus() {
        APIClient.fetchGuaranteePlan { result in
            switch result {
            case .success(let fetchedPlan):
                self.plan = fetchedPlan
                DispatchQueue.main.async { self.updateUI() }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.presentAlert(title: LanguageManager.shared.localizedString(for: "error_title"), message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func reportCompletion() {
        guard let planId = plan?.id else { return }
        APIClient.reportGuaranteeCompletion(planId: planId, date: Date()) { result in
            switch result {
            case .success(let updatedPlan):
                self.plan = updatedPlan
                DispatchQueue.main.async { self.updateUI() }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.presentAlert(title: LanguageManager.shared.localizedString(for: "error_title"), message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - UI Update

    private func updateUI() {
        guard let plan = plan else { return }
        streakLabel.text = String(format: LanguageManager.shared.localizedString(for: "streak_progress_format"), plan.streakCount)
        let progress = Float(plan.streakCount) / 30.0
        progressView.setProgress(progress, animated: true)

        if plan.state == .active && plan.streakCount < 30 {
            completeButton.isEnabled = true
            completeButton.setTitle(LanguageManager.shared.localizedString(for: "mission_complete_today"), for: .normal)
        } else {
            let title = plan.state == .refunded ? LanguageManager.shared.localizedString(for: "status_refunded") : LanguageManager.shared.localizedString(for: "status_charged")
            completeButton.setTitle(title, for: .normal)
            completeButton.isEnabled = false
        }
    }

    // MARK: - Helpers

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
        present(alert, animated: true)
    }
}
