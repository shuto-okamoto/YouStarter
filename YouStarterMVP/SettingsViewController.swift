// SettingsViewController.swift

import UIKit

extension Notification.Name {
    static let settingsDidSave = Notification.Name("settingsDidSave")
}

class SettingsViewController: UIViewController, UITextFieldDelegate, VideoManagerDelegate {
    // MARK: - UI Elements
    private let timePicker      = UIDatePicker()
    private let saveButton      = UIButton(type: .system)
    private let languageButton  = UIButton(type: .system)
    private let countryButton   = UIButton(type: .system)

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "settings")
        view.backgroundColor = .systemGroupedBackground
        
        // Set up VideoManager delegate (fallback for other tabs)
        if VideoManager.shared.delegate == nil {
            VideoManager.shared.delegate = self
        }
        
        loadDefaults()
        setupUI()
        setupActions()
    }

    // MARK: - Defaults Loading
    private func loadDefaults() {
        let defaults = UserDefaults.standard
        if let savedTime = defaults.object(forKey: "playTime") as? Date {
            timePicker.date = savedTime
        }
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Labels
        let timeLabel = UILabel()
        timeLabel.text = LanguageManager.shared.localizedString(for: "play_time")
        let languageLabel = UILabel()
        languageLabel.text = LanguageManager.shared.localizedString(for: "language")
        let countryLabel = UILabel()
        countryLabel.text = LanguageManager.shared.localizedString(for: "country")

        // Configure timePicker
        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .wheels
        updateTimePickerLocale()

        // Configure buttons
        saveButton.setTitle(LanguageManager.shared.localizedString(for: "save_and_close"), for: .normal)
        
        // Configure language button
        let currentLanguage = LanguageManager.shared.currentLanguage
        print("SettingsViewController: 言語ボタン初期化 - 現在の言語: \(currentLanguage.displayName)")
        languageButton.setTitle("\(currentLanguage.flag) \(currentLanguage.displayName)", for: .normal)
        languageButton.setTitleColor(.systemBlue, for: .normal)
        languageButton.contentHorizontalAlignment = .left
        
        // Configure country button
        let currentCountry = getCurrentCountry()
        countryButton.setTitle("\(currentCountry.flag) \(currentCountry.name)", for: .normal)
        countryButton.setTitleColor(.systemBlue, for: .normal)
        countryButton.contentHorizontalAlignment = .left

        // Add subviews
        [timeLabel, timePicker,
         languageLabel, languageButton,
         countryLabel, countryButton,
         saveButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        // Layout
        NSLayoutConstraint.activate([
            // Time picker
            timeLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            timePicker.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 5),
            timePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            timePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Country
            countryLabel.topAnchor.constraint(equalTo: timePicker.bottomAnchor, constant: 20),
            countryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            countryButton.topAnchor.constraint(equalTo: countryLabel.bottomAnchor, constant: 5),
            countryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            countryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            countryButton.heightAnchor.constraint(equalToConstant: 44),

            // Language
            languageLabel.topAnchor.constraint(equalTo: countryButton.bottomAnchor, constant: 20),
            languageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            languageButton.topAnchor.constraint(equalTo: languageLabel.bottomAnchor, constant: 5),
            languageButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            languageButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            languageButton.heightAnchor.constraint(equalToConstant: 44),

            // Save button
            saveButton.topAnchor.constraint(equalTo: languageButton.bottomAnchor, constant: 30),
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    // MARK: - Actions Setup
    private func setupActions() {
        saveButton.addTarget(self,      action: #selector(saveSettings),    for: .touchUpInside)
        languageButton.addTarget(self,  action: #selector(selectLanguage),  for: .touchUpInside)
        countryButton.addTarget(self,   action: #selector(selectCountry),   for: .touchUpInside)
    }

    // MARK: - Country Selection
    struct Country {
        let name: String
        let flag: String
        let locale: String
        let timeZone: String
    }
    
    private let supportedCountries: [Country] = [
        Country(name: "Japan", flag: "🇯🇵", locale: "ja_JP", timeZone: "Asia/Tokyo"),
        Country(name: "United States", flag: "🇺🇸", locale: "en_US", timeZone: "America/New_York"),
        Country(name: "United Kingdom", flag: "🇬🇧", locale: "en_GB", timeZone: "Europe/London"),
        Country(name: "Germany", flag: "🇩🇪", locale: "de_DE", timeZone: "Europe/Berlin"),
        Country(name: "France", flag: "🇫🇷", locale: "fr_FR", timeZone: "Europe/Paris"),
        Country(name: "Australia", flag: "🇦🇺", locale: "en_AU", timeZone: "Australia/Sydney"),
        Country(name: "Canada", flag: "🇨🇦", locale: "en_CA", timeZone: "America/Toronto"),
        Country(name: "South Korea", flag: "🇰🇷", locale: "ko_KR", timeZone: "Asia/Seoul"),
        Country(name: "China", flag: "🇨🇳", locale: "zh_CN", timeZone: "Asia/Shanghai"),
        Country(name: "Brazil", flag: "🇧🇷", locale: "pt_BR", timeZone: "America/Sao_Paulo")
    ]
    
    private func getCurrentCountry() -> Country {
        let savedCountryLocale = UserDefaults.standard.string(forKey: "selectedCountryLocale") ?? "ja_JP"
        return supportedCountries.first { $0.locale == savedCountryLocale } ?? supportedCountries[0]
    }
    
    private func updateTimePickerLocale() {
        let currentCountry = getCurrentCountry()
        timePicker.locale = Locale(identifier: currentCountry.locale)
    }

    // MARK: - Save Settings
    @objc private func saveSettings() {
        let defaults = UserDefaults.standard
        // Always use recommended mode (mode 0) since we removed the selection
        defaults.set(0, forKey: "videoMode")
        defaults.set(timePicker.date, forKey: "playTime")
        if let comps = Calendar.current.dateComponents([.hour, .minute], from: timePicker.date) as DateComponents?,
           let h = comps.hour, let m = comps.minute {
            defaults.set("\(h)", forKey: "alarmHour")
            defaults.set("\(m)", forKey: "alarmMinute")
            NotificationManager.shared.scheduleDailyAlarm(hour: h, minute: m)
        }
        NotificationCenter.default.post(name: .settingsDidSave, object: nil)

        // 保存完了のアラートを表示し、OKボタンのハンドラ内でホーム画面へ遷移
        let alert = UIAlertController(
            title: LanguageManager.shared.localizedString(for: "settings_saved_title"),
            message: LanguageManager.shared.localizedString(for: "settings_saved_message"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default, handler: { _ in
            self.tabBarController?.selectedIndex = 0
        }))
        present(alert, animated: true)
    }

    // MARK: - Country Selection
    @objc private func selectCountry() {
        let alertController = UIAlertController(
            title: LanguageManager.shared.localizedString(for: "country_selection"),
            message: nil,
            preferredStyle: .actionSheet
        )
        
        for country in supportedCountries {
            let action = UIAlertAction(
                title: "\(country.flag) \(country.name)",
                style: .default
            ) { _ in
                self.changeCountry(to: country)
            }
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "cancel"), style: .cancel))
        
        // iPad support
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = countryButton
            popover.sourceRect = countryButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func changeCountry(to country: Country) {
        UserDefaults.standard.set(country.locale, forKey: "selectedCountryLocale")
        countryButton.setTitle("\(country.flag) \(country.name)", for: .normal)
        updateTimePickerLocale()
    }

    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    // MARK: - VideoManagerDelegate
    func videoManager(_ manager: VideoManager, didUpdateMinimizedState isMinimized: Bool) {
        // No specific UI updates needed in Settings tab
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
        // No specific action needed in Settings tab
    }
    
    // MARK: - Language Selection
    @objc private func selectLanguage() {
        print("🌐 SettingsViewController: 言語選択アラートを表示します")
        print("🌐 SettingsViewController: Showing language selection alert")
        
        let alertController = UIAlertController(
            title: LanguageManager.shared.localizedString(for: "language_selection"),
            message: nil,
            preferredStyle: .actionSheet
        )
        
        for language in LanguageManager.SupportedLanguage.allCases {
            let action = UIAlertAction(
                title: "\(language.flag) \(language.displayName)",
                style: .default
            ) { _ in
                print("🌐 SettingsViewController: \(language.displayName) が選択されました")
                print("🌐 SettingsViewController: \(language.displayName) was selected")
                self.changeLanguage(to: language)
            }
            
            if language == LanguageManager.shared.currentLanguage {
                action.setValue(true, forKey: "checked")
            }
            
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(
            title: LanguageManager.shared.localizedString(for: "cancel"),
            style: .cancel
        ))
        
        // For iPad support
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = languageButton
            popover.sourceRect = languageButton.bounds
        }
        
        present(alertController, animated: true)
    }
    
    private func changeLanguage(to language: LanguageManager.SupportedLanguage) {
        print("SettingsViewController: 言語変更開始 - 新しい言語: \(language.displayName)")
        
        // Check if language is actually changing
        let currentLang = LanguageManager.shared.currentLanguage
        if currentLang == language {
            print("SettingsViewController: 同じ言語が選択されました。変更をスキップします。")
            return
        }
        
        print("SettingsViewController: 言語を \(currentLang.displayName) から \(language.displayName) に変更中")
        
        LanguageManager.shared.currentLanguage = language
        
        // Update button text immediately  
        languageButton.setTitle("\(language.flag) \(language.displayName)", for: .normal)
        
        print("SettingsViewController: 言語設定完了、再起動アラートを表示します")
        
        // Show restart alert
        LanguageManager.shared.showLanguageRestartAlert(in: self)
    }
}
