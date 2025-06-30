//
//  LanguageManager.swift
//  YouStarterMVP
//
//  Language management for internationalization
//

import Foundation
import UIKit

class LanguageManager {
    static let shared = LanguageManager()
    
    private let languageKey = "selectedLanguage"
    
    enum SupportedLanguage: String, CaseIterable {
        case japanese = "ja"
        case english = "en"
        case chinese = "zh-Hans"
        
        var displayName: String {
            switch self {
            case .japanese: return "日本語"
            case .english: return "English"
            case .chinese: return "中文 (简体)"
            }
        }
        
        var flag: String {
            switch self {
            case .japanese: return "🇯🇵"
            case .english: return "🇺🇸"
            case .chinese: return "🇨🇳"
            }
        }
    }
    
    private init() {}
    
    var currentLanguage: SupportedLanguage {
        get {
            let savedLanguage = UserDefaults.standard.string(forKey: languageKey)
            return SupportedLanguage(rawValue: savedLanguage ?? "ja") ?? .japanese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
            setAppLanguage(newValue.rawValue)
        }
    }
    
    private func setAppLanguage(_ languageCode: String) {
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    func localizedString(for key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // Fallback to main bundle
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
        
        // Force use the specific language bundle
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    
    func showLanguageRestartAlert(in viewController: UIViewController) {
        print("LanguageManager: 言語変更アラートを表示中 - 現在の言語: \(currentLanguage.displayName)")
        
        // Update tab titles immediately
        updateAllTabTitles()
        
        // Re-schedule notifications with new language
        rescheduleNotificationsForLanguageChange()
        
        // Notify all view controllers about language change
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
        
        let title = localizedString(for: "language_changed_title")
        let message = localizedString(for: "language_changed_message")
        let restartButton = localizedString(for: "restart_app")
        
        print("LanguageManager: アラート内容 - タイトル: \(title), メッセージ: \(message), ボタン: \(restartButton)")
        
        // Directly show termination recommendation instead of intermediate confirmation
        print("🔄 LanguageManager: 言語変更完了 - 終了勧告を表示します")
        print("🔄 LanguageManager: Language change completed - showing termination recommendation")
        self.showTerminationRecommendation(in: viewController)
    }
    
    /// Show termination recommendation after language change confirmation
    private func showTerminationRecommendation(in viewController: UIViewController) {
        print("🔄 LanguageManager: 終了勧告アラートを表示中")
        print("🔄 LanguageManager: Showing termination recommendation alert")
        
        let title = localizedString(for: "termination_recommendation_title")
        let message = localizedString(for: "termination_recommendation_message")
        let terminateButton = localizedString(for: "restart_app")
        let laterButton = localizedString(for: "later")
        
        print("LanguageManager: 終了勧告内容 - タイトル: \(title), メッセージ: \(message)")
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        // Terminate now button
        alert.addAction(UIAlertAction(title: terminateButton, style: .destructive) { _ in
            print("🔄 LanguageManager: 今すぐ終了ボタンがタップされました")
            print("🔄 LanguageManager: Terminate now button tapped")
            self.restartApp()
        })
        
        // Later button
        alert.addAction(UIAlertAction(title: laterButton, style: .default) { _ in
            print("🔄 LanguageManager: 後でボタンがタップされました - フラグを保持")
            print("🔄 LanguageManager: Later button tapped - keeping restart flag")
            // Keep the flag so the restart alert can be shown later
            // User can restart manually later or see the alert on next app usage
        })
        
        viewController.present(alert, animated: true) {
            print("🔄 LanguageManager: 終了勧告アラート表示完了")
            print("🔄 LanguageManager: Termination recommendation alert presentation completed")
        }
    }
    
    /// Update all tab titles when language changes
    func updateAllTabTitles() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBarController = window.rootViewController as? UITabBarController else {
            return
        }
        
        // Update tab titles
        if let viewControllers = tabBarController.viewControllers {
            for (index, vc) in viewControllers.enumerated() {
                switch index {
                case 0: // Home
                    vc.tabBarItem.title = localizedString(for: "tab_home")
                case 1: // Results
                    vc.tabBarItem.title = localizedString(for: "tab_results")
                case 2: // Challenge
                    vc.tabBarItem.title = localizedString(for: "tab_challenge")
                case 3: // Wallet
                    vc.tabBarItem.title = localizedString(for: "tab_wallet")
                case 4: // Settings
                    vc.tabBarItem.title = localizedString(for: "tab_settings")
                default:
                    break
                }
            }
        }
    }
    
    private func restartApp() {
        print("🔄 LanguageManager: 言語変更のためアプリを終了します")
        print("🔄 LanguageManager: Language change app termination initiated")
        
        // Use immediate termination for language change
        DispatchQueue.main.async {
            print("🔄 LanguageManager: Executing immediate app termination...")
            
            // Immediate forced termination for language change
            exit(0)
        }
    }
    
    
    // MARK: - Currency Conversion
    
    /// Convert yen amount to appropriate currency based on current language
    /// 1000 yen = $10, 5000 yen = $50, 10000 yen = $100
    func formatCurrency(yenAmount: Int) -> String {
        switch currentLanguage {
        case .japanese:
            return "\(yenAmount)円"
        case .chinese:
            let yuanAmount = yenAmount / 100 // 1000円 → 10元
            return "\(yuanAmount)元"
        case .english:
            let dollarAmount = yenAmount / 100 // 1000円 → $10
            return "$\(dollarAmount)"
        }
    }
    
    /// Get currency symbol based on current language
    func getCurrencySymbol() -> String {
        switch currentLanguage {
        case .japanese: return "円"
        case .chinese: return "元"
        case .english: return "$"
        }
    }
    
    /// Convert yen to dollar amount (for internal calculations)
    func convertYenToDollar(_ yenAmount: Int) -> Int {
        return yenAmount / 100
    }
    
    /// Convert dollar to yen amount (for internal calculations)
    func convertDollarToYen(_ dollarAmount: Int) -> Int {
        return dollarAmount * 100
    }
    
    /// Re-schedule notifications when language changes
    private func rescheduleNotificationsForLanguageChange() {
        let defaults = UserDefaults.standard
        
        // Get current alarm settings
        let hour: Int
        let minute: Int
        if let hs = defaults.string(forKey: "alarmHour"),
           let ms = defaults.string(forKey: "alarmMinute"),
           let hh = Int(hs), let mm = Int(ms) {
            hour = hh
            minute = mm
        } else {
            hour = 7
            minute = 0
        }
        
        // Re-schedule daily alarm with new language
        NotificationManager.shared.scheduleDailyAlarm(
            hour: hour,
            minute: minute,
            categoryIdentifier: "DAILY_ALARM"
        )
        
        print("LanguageManager: Re-scheduled notifications for language change")
    }
}