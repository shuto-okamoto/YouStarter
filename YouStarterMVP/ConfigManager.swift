//
//  ConfigManager.swift
//  YouStarterMVP
//
//  Configuration manager for app settings loaded from JSON file
//

import Foundation

struct VideoConfig: Codable {
    let id: Int
    let title_ja: String
    let title_en: String
    let url: String
    
    func getTitle(for language: LanguageManager.SupportedLanguage) -> String {
        return language == .japanese ? title_ja : title_en
    }
}

struct SayingConfig: Codable {
    let id: Int
    let text_ja: String
    let text_en: String
    
    func getText(for language: LanguageManager.SupportedLanguage) -> String {
        return language == .japanese ? text_ja : text_en
    }
}

struct AppConfig: Codable {
    let fallback_video_urls: [VideoConfig]
    let sayings: [SayingConfig]
}

class ConfigManager {
    static let shared = ConfigManager()
    
    private var config: AppConfig?
    
    private init() {
        loadConfig()
    }
    
    private func loadConfig() {
        guard let path = Bundle.main.path(forResource: "AppConfig", ofType: "json"),
              let data = NSData(contentsOfFile: path) as Data? else {
            print("ConfigManager: Failed to find AppConfig.json")
            return
        }
        
        do {
            config = try JSONDecoder().decode(AppConfig.self, from: data)
            print("ConfigManager: Successfully loaded config with \(config?.fallback_video_urls.count ?? 0) fallback videos and \(config?.sayings.count ?? 0) sayings")
        } catch {
            print("ConfigManager: Failed to decode config - \(error)")
        }
    }
    
    // MARK: - Video URLs
    
    func getFallbackVideoConfigs() -> [VideoConfig] {
        return config?.fallback_video_urls ?? []
    }
    
    func getFallbackVideoURL(at index: Int) -> String? {
        guard let config = config, index < config.fallback_video_urls.count else {
            return nil
        }
        return config.fallback_video_urls[index].url
    }
    
    func getFallbackVideoTitle(at index: Int, for language: LanguageManager.SupportedLanguage = LanguageManager.shared.currentLanguage) -> String? {
        guard let config = config, index < config.fallback_video_urls.count else {
            return nil
        }
        return config.fallback_video_urls[index].getTitle(for: language)
    }
    
    // MARK: - Sayings
    
    func getSayingConfigs() -> [SayingConfig] {
        return config?.sayings ?? []
    }
    
    func getSaying(at index: Int, for language: LanguageManager.SupportedLanguage = LanguageManager.shared.currentLanguage) -> String {
        guard let config = config, index < config.sayings.count else {
            // Fallback to localized strings if config fails
            return LanguageManager.shared.localizedString(for: "saying_\(index)")
        }
        return config.sayings[index].getText(for: language)
    }
    
    func getTotalSayingsCount() -> Int {
        return config?.sayings.count ?? 30
    }
    
    // MARK: - Reload Config (for future updates)
    
    func reloadConfig() {
        loadConfig()
    }
}