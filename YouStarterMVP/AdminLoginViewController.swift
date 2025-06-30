//
//  AdminLoginViewController.swift
//  YouStarterMVP
//
//  Created by 岡本秀斗 on 2025/06/28.
//

import UIKit

class AdminLoginViewController: UIViewController {

    // MARK: - UI Elements
    private let passwordLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = LanguageManager.shared.localizedString(for: "admin_password_label")
        lbl.font = .preferredFont(forTextStyle: .headline)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let passwordField: UITextField = {
        let tf = UITextField()
        tf.isSecureTextEntry = true
        tf.borderStyle = .roundedRect
        tf.placeholder = LanguageManager.shared.localizedString(for: "admin_password_placeholder")
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let loginButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(LanguageManager.shared.localizedString(for: "admin_login_button"), for: .normal)
        btn.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "admin_panel_title")
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        view.addSubview(passwordLabel)
        view.addSubview(passwordField)
        view.addSubview(loginButton)

        NSLayoutConstraint.activate([
            passwordLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            passwordLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            passwordLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            passwordField.topAnchor.constraint(equalTo: passwordLabel.bottomAnchor, constant: 12),
            passwordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            passwordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            loginButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 24),
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        passwordField.delegate = self
    }

    // MARK: - Actions
    @objc private func loginTapped() {
        let input = passwordField.text ?? ""
        let correctPassword = UserDefaults.standard.string(forKey: "adminPassword") ?? "admin123"
        if input == correctPassword {
            let adminVC = AdminPanelViewController()
            navigationController?.pushViewController(adminVC, animated: true)
        } else {
            let alert = UIAlertController(title: LanguageManager.shared.localizedString(for: "error_title"), message: LanguageManager.shared.localizedString(for: "admin_password_incorrect"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - UITextFieldDelegate
extension AdminLoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        passwordField.resignFirstResponder()
        loginTapped()
        return true
    }
}
