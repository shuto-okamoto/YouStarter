//
//  KeywordManager.swift
//  YouStarterMVP
//
//  Manages video search keywords with automatic translation
//

import Foundation

class KeywordManager {
    static let shared = KeywordManager()
    private init() {}
    
    // Base keywords in Japanese (admin-configured)
    private let keywordsKey = "videoSearchKeywords"
    private let currentKeywordIndexKey = "currentKeywordIndex"
    
    // Default keywords if none configured
    private let defaultKeywords = [
        "副業",
        "起業",
        "投資",
        "ビジネス",
        "自己啓発",
        "お金儲け",
        "成功法則",
        "マーケティング"
    ]
    
    // Keyword translations for supported languages
    private let keywordTranslations: [String: [String: String]] = [
        "副業": [
            "en": "side business",
            "zh-Hans": "副业",
            "ko": "부업",
            "es": "negocio secundario",
            "fr": "activité secondaire",
            "de": "Nebentätigkeit",
            "pt": "negócio paralelo",
            "ru": "подработка",
            "ar": "عمل جانبي"
        ],
        "起業": [
            "en": "entrepreneurship",
            "zh-Hans": "创业",
            "ko": "창업",
            "es": "emprendimiento",
            "fr": "entrepreneuriat",
            "de": "Unternehmertum",
            "pt": "empreendedorismo",
            "ru": "предпринимательство",
            "ar": "ريادة الأعمال"
        ],
        "投資": [
            "en": "investment",
            "zh-Hans": "投资",
            "ko": "투자",
            "es": "inversión",
            "fr": "investissement",
            "de": "Investition",
            "pt": "investimento",
            "ru": "инвестиции",
            "ar": "استثمار"
        ],
        "ビジネス": [
            "en": "business",
            "zh-Hans": "商业",
            "ko": "비즈니스",
            "es": "negocio",
            "fr": "entreprise",
            "de": "Geschäft",
            "pt": "negócio",
            "ru": "бизнес",
            "ar": "عمل تجاري"
        ],
        "自己啓発": [
            "en": "self development",
            "zh-Hans": "自我发展",
            "ko": "자기계발",
            "es": "desarrollo personal",
            "fr": "développement personnel",
            "de": "Persönlichkeitsentwicklung",
            "pt": "desenvolvimento pessoal",
            "ru": "саморазвитие",
            "ar": "تطوير الذات"
        ],
        "お金儲け": [
            "en": "making money",
            "zh-Hans": "赚钱",
            "ko": "돈벌기",
            "es": "ganar dinero",
            "fr": "gagner de l'argent",
            "de": "Geld verdienen",
            "pt": "ganhar dinheiro",
            "ru": "зарабатывать деньги",
            "ar": "كسب المال"
        ],
        "成功法則": [
            "en": "success principles",
            "zh-Hans": "成功法则",
            "ko": "성공법칙",
            "es": "principios de éxito",
            "fr": "principes de succès",
            "de": "Erfolgsprinzipien",
            "pt": "princípios de sucesso",
            "ru": "принципы успеха",
            "ar": "مبادئ النجاح"
        ],
        "マーケティング": [
            "en": "marketing",
            "zh-Hans": "营销",
            "ko": "마케팅",
            "es": "marketing",
            "fr": "marketing",
            "de": "Marketing",
            "pt": "marketing",
            "ru": "маркетинг",
            "ar": "تسويق"
        ]
    ]
    
    // MARK: - Public Methods
    
    /// Get current keyword for video search, translated to user's language
    func getCurrentKeyword() -> String {
        let keywords = getConfiguredKeywords()
        let currentIndex = UserDefaults.standard.integer(forKey: currentKeywordIndexKey)
        let adjustedIndex = currentIndex % keywords.count
        let baseKeyword = keywords[adjustedIndex]
        
        // Get translated keyword based on user's language
        return getTranslatedKeyword(baseKeyword)
    }
    
    /// Rotate to next keyword for variety
    func rotateToNextKeyword() {
        let keywords = getConfiguredKeywords()
        let currentIndex = UserDefaults.standard.integer(forKey: currentKeywordIndexKey)
        let nextIndex = (currentIndex + 1) % keywords.count
        UserDefaults.standard.set(nextIndex, forKey: currentKeywordIndexKey)
    }
    
    /// Get all configured keywords (Japanese base)
    func getConfiguredKeywords() -> [String] {
        return UserDefaults.standard.stringArray(forKey: keywordsKey) ?? defaultKeywords
    }
    
    /// Set keywords (admin function)
    func setKeywords(_ keywords: [String]) {
        UserDefaults.standard.set(keywords, forKey: keywordsKey)
        // Reset index when keywords change
        UserDefaults.standard.set(0, forKey: currentKeywordIndexKey)
    }
    
    /// Add a keyword (admin function)
    func addKeyword(_ keyword: String) {
        var keywords = getConfiguredKeywords()
        if !keywords.contains(keyword) {
            keywords.append(keyword)
            setKeywords(keywords)
        }
    }
    
    /// Remove a keyword (admin function)
    func removeKeyword(_ keyword: String) {
        var keywords = getConfiguredKeywords()
        keywords.removeAll { $0 == keyword }
        if keywords.isEmpty {
            keywords = defaultKeywords
        }
        setKeywords(keywords)
    }
    
    // MARK: - Private Methods
    
    private func getTranslatedKeyword(_ baseKeyword: String) -> String {
        let currentLanguage = LanguageManager.shared.currentLanguage.rawValue
        
        // If Japanese or no translation available, return original
        guard currentLanguage != "ja",
              let translations = keywordTranslations[baseKeyword],
              let translatedKeyword = translations[currentLanguage] else {
            return baseKeyword
        }
        
        return translatedKeyword
    }
}