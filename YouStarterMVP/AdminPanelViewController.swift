//
//  AdminPanelViewController.swift
//  YouStarterMVP
//
//  Created by You on 2025/06/28.
//  Updated to allow 5 URLs and exclusive selection switch

import UIKit

class AdminPanelViewController: UIViewController, UITextFieldDelegate {

    // MARK: - UI Elements (キーワード管理のみ)
    private let saveButton = UIBarButtonItem()
    private var keywordTextFields: [UITextField] = []
    private let addKeywordButton = UIButton(type: .system)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "admin_panel_title")
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupForm()
        loadSavedData()
    }

    // MARK: - Setup
    private func setupNavigationBar() {
        saveButton.title = LanguageManager.shared.localizedString(for: "admin_save_button")
        saveButton.style = .done
        saveButton.target = self
        saveButton.action = #selector(saveList)
        navigationItem.rightBarButtonItem = saveButton
    }

    private func setupForm() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 15
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        // 従来のURL機能は削除（キーワードベースに統一）

        // Keyword Management Section
        let keywordHeader = UILabel()
        keywordHeader.text = LanguageManager.shared.localizedString(for: "admin_keyword_management")
        keywordHeader.font = UIFont.boldSystemFont(ofSize: 20)
        keywordHeader.textAlignment = .center
        contentStack.addArrangedSubview(keywordHeader)

        let keywordDescription = UILabel()
        keywordDescription.text = LanguageManager.shared.localizedString(for: "admin_keyword_description")
        keywordDescription.font = UIFont.systemFont(ofSize: 14)
        keywordDescription.textColor = .secondaryLabel
        keywordDescription.numberOfLines = 0
        keywordDescription.textAlignment = .center
        contentStack.addArrangedSubview(keywordDescription)

        setupKeywordFields(in: contentStack)

        addKeywordButton.setTitle(LanguageManager.shared.localizedString(for: "admin_add_keyword"), for: .normal)
        addKeywordButton.backgroundColor = .systemGreen
        addKeywordButton.setTitleColor(.white, for: .normal)
        addKeywordButton.layer.cornerRadius = 8
        addKeywordButton.addTarget(self, action: #selector(addKeywordField), for: .touchUpInside)
        contentStack.addArrangedSubview(addKeywordButton)

        // Auto Layout
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }
    
    private func setupKeywordFields(in stackView: UIStackView) {
        let keywords = KeywordManager.shared.getConfiguredKeywords()
        
        for keyword in keywords {
            let textField = createKeywordTextField()
            textField.text = keyword
            keywordTextFields.append(textField)
            
            let deleteButton = UIButton(type: .system)
            deleteButton.setTitle(LanguageManager.shared.localizedString(for: "admin_delete_button"), for: .normal)
            deleteButton.setTitleColor(.systemRed, for: .normal)
            deleteButton.addTarget(self, action: #selector(deleteKeywordField(_:)), for: .touchUpInside)
            
            let rowStack = UIStackView(arrangedSubviews: [textField, deleteButton])
            rowStack.axis = .horizontal
            rowStack.alignment = .center
            rowStack.spacing = 10
            stackView.addArrangedSubview(rowStack)
        }
    }
    
    private func createKeywordTextField() -> UITextField {
        let textField = UITextField()
        textField.placeholder = LanguageManager.shared.localizedString(for: "admin_keyword_placeholder")
        textField.borderStyle = .roundedRect
        textField.returnKeyType = .done
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }

    // MARK: - Actions (スイッチ関連は削除)

    @objc private func saveList() {
        // Save keywords only (URL feature removed)
        let keywords = keywordTextFields.compactMap { textField in
            let keyword = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return keyword.isEmpty ? nil : keyword
        }
        KeywordManager.shared.setKeywords(keywords)
        
        // Feedback
        let alert = UIAlertController(title: LanguageManager.shared.localizedString(for: "admin_save_complete"), message: LanguageManager.shared.localizedString(for: "admin_keywords_updated"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
        present(alert, animated: true)
    }
    
    @objc private func addKeywordField() {
        let textField = createKeywordTextField()
        keywordTextFields.append(textField)
        
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle(LanguageManager.shared.localizedString(for: "admin_delete_button"), for: .normal)
        deleteButton.setTitleColor(.systemRed, for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteKeywordField(_:)), for: .touchUpInside)
        
        let rowStack = UIStackView(arrangedSubviews: [textField, deleteButton])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 10
        
        // Find the content stack and insert before the add button
        if let scrollView = view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView,
           let contentStack = scrollView.subviews.first(where: { $0 is UIStackView }) as? UIStackView {
            let insertIndex = contentStack.arrangedSubviews.count - 1
            contentStack.insertArrangedSubview(rowStack, at: insertIndex)
        }
    }
    
    @objc private func deleteKeywordField(_ sender: UIButton) {
        guard let rowStack = sender.superview as? UIStackView,
              let contentStack = rowStack.superview as? UIStackView else { return }
        
        // Find the text field in this row and remove it from our array
        if let textField = rowStack.arrangedSubviews.first(where: { $0 is UITextField }) as? UITextField,
           let index = keywordTextFields.firstIndex(of: textField) {
            keywordTextFields.remove(at: index)
        }
        
        // Remove the entire row
        contentStack.removeArrangedSubview(rowStack)
        rowStack.removeFromSuperview()
    }

    // MARK: - Persistence
    private func loadSavedData() {
        // URL関連のデータ読み込みは削除（キーワードのみ）
        // Keywords are loaded in setupKeywordFields
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
