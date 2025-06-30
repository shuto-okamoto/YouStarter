//
//  GuaranteePlanViewController.swift
//  YouStarterMVP
//
//  Created by You on 2025/06/28.
//

import UIKit
import PassKit  // for Apple Pay integration, if needed

class GuaranteePlanViewController: UIViewController {

    // MARK: - UI Elements

    private let amountPicker = UIPickerView()
    private let startButton  = UIButton(type: .system)

    // Example deposit options
    private let depositOptions = [500, 1000, 5000, 10000]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "guarantee_plan")
        view.backgroundColor = .systemBackground

        setupPicker()
        setupStartButton()
    }

    // MARK: - Setup

    private func setupPicker() {
        amountPicker.dataSource = self
        amountPicker.delegate   = self
        amountPicker.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(amountPicker)

        NSLayoutConstraint.activate([
            amountPicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            amountPicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            amountPicker.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            amountPicker.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    private func setupStartButton() {
        startButton.setTitle(LanguageManager.shared.localizedString(for: "start_plan"), for: .normal)
        // Use preferredFont for text style headline
        startButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startPlan), for: .touchUpInside)
        view.addSubview(startButton)

        NSLayoutConstraint.activate([
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.topAnchor.constraint(equalTo: amountPicker.bottomAnchor, constant: 30)
        ])
    }

    // MARK: - Actions

    @objc private func startPlan() {
        let selectedRow = amountPicker.selectedRow(inComponent: 0)
        let deposit = depositOptions[selectedRow]

        // 1) Call server API to create plan and get paymentIntentID
        APIClient.createGuaranteePlan(depositAmount: deposit) { result in
            switch result {
            case .success(let plan):
                // 2) Launch Apple Pay or Stripe flow with plan.paymentIntentID
                DispatchQueue.main.async {
                    self.presentPaymentSheet(for: plan.paymentIntentID)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.presentAlert(title: LanguageManager.shared.localizedString(for: "error_title"), message: error.localizedDescription)
                }
            }
        }
    }

    private func presentPaymentSheet(for paymentIntentID: String) {
        // Stub: integrate your Apple Pay / Stripe SDK here,
        // using paymentIntentID for authorization.
        // On success, navigate to PlanStatusViewController.
        let statusVC = PlanStatusViewController()
        navigationController?.pushViewController(statusVC, animated: true)
    }

    // MARK: - Helpers

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIPickerViewDataSource / Delegate

extension GuaranteePlanViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        depositOptions.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int,
                    forComponent component: Int) -> String? {
        LanguageManager.shared.formatCurrency(yenAmount: depositOptions[row])
    }
}
