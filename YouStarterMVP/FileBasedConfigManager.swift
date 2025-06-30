//
//  FileBasedConfigManager.swift
//  YouStarterMVP
//
//  External file-based configuration manager for keywords and sayings
//

import Foundation

class FileBasedConfigManager {
    static let shared = FileBasedConfigManager()
    
    private let keywordsFileName = "keywords.csv"
    private let sayingsFileName = "sayings.csv"
    
    private init() {}
    
    // MARK: - File Paths
    
    private func getProjectDirectoryPath() -> String? {
        // Get the path to the YouStarterMVP project directory (parent of the app bundle)
        let bundlePath = Bundle.main.bundlePath
        let projectPath = (bundlePath as NSString).deletingLastPathComponent
        return projectPath
    }
    
    private func getKeywordsFilePath() -> String? {
        guard let projectPath = getProjectDirectoryPath() else { return nil }
        return "\(projectPath)/\(keywordsFileName)"
    }
    
    private func getSayingsFilePath() -> String? {
        guard let projectPath = getProjectDirectoryPath() else { return nil }
        return "\(projectPath)/\(sayingsFileName)"
    }
    
    // MARK: - Keywords Management
    
    func loadKeywords() -> [(japanese: String, english: String, chinese: String)] {
        guard let filePath = getKeywordsFilePath(),
              FileManager.default.fileExists(atPath: filePath) else {
            print("FileBasedConfigManager: keywords.csv not found, using defaults")
            return getDefaultKeywords()
        }
        
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            return parseKeywordsCSV(content)
        } catch {
            print("FileBasedConfigManager: Error reading keywords.csv: \(error)")
            return getDefaultKeywords()
        }
    }
    
    private func parseKeywordsCSV(_ content: String) -> [(japanese: String, english: String, chinese: String)] {
        // Remove BOM if present
        let cleanedContent = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content
        let lines = cleanedContent.components(separatedBy: .newlines)
        var keywords: [(japanese: String, english: String, chinese: String)] = []
        
        // Skip header line
        for line in lines.dropFirst() {
            let components = line.components(separatedBy: ",")
            if components.count >= 3 {
                let japanese = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let english = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let chinese = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !japanese.isEmpty && !english.isEmpty && !chinese.isEmpty {
                    keywords.append((japanese: japanese, english: english, chinese: chinese))
                }
            }
        }
        
        print("FileBasedConfigManager: Loaded \(keywords.count) keywords from CSV")
        return keywords
    }
    
    private func getDefaultKeywords() -> [(japanese: String, english: String, chinese: String)] {
        return [
            ("モチベーション", "motivation", "动机"),
            ("成功", "success", "成功"),
            ("習慣", "habits", "习惯"),
            ("目標達成", "goal achievement", "目标达成"),
            ("自己啓発", "self improvement", "自我提升")
        ]
    }
    
    func getCurrentKeyword() -> String {
        let keywords = loadKeywords()
        guard !keywords.isEmpty else { return "motivation" }
        
        let currentLanguage = LanguageManager.shared.currentLanguage
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % keywords.count
        
        let selectedKeyword = keywords[index]
        
        // Return keyword based on current language
        switch currentLanguage {
        case .japanese:
            return selectedKeyword.japanese
        case .english:
            return selectedKeyword.english
        case .chinese:
            return selectedKeyword.chinese
        }
    }
    
    // MARK: - Sayings Management
    
    func loadSayings() -> [(japanese: String, english: String)] {
        guard let filePath = getSayingsFilePath(),
              FileManager.default.fileExists(atPath: filePath) else {
            print("FileBasedConfigManager: sayings.csv not found, using defaults")
            return getDefaultSayings()
        }
        
        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            return parseSayingsCSV(content)
        } catch {
            print("FileBasedConfigManager: Error reading sayings.csv: \(error)")
            return getDefaultSayings()
        }
    }
    
    private func parseSayingsCSV(_ content: String) -> [(japanese: String, english: String)] {
        // Remove BOM if present
        let cleanedContent = content.hasPrefix("\u{FEFF}") ? String(content.dropFirst()) : content
        let lines = cleanedContent.components(separatedBy: .newlines)
        var sayings: [(japanese: String, english: String)] = []
        
        // Skip header line
        for line in lines.dropFirst() {
            let components = line.components(separatedBy: ",")
            if components.count >= 2 {
                let japanese = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let english = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !japanese.isEmpty && !english.isEmpty {
                    sayings.append((japanese: japanese, english: english))
                }
            }
        }
        
        print("FileBasedConfigManager: Loaded \(sayings.count) sayings from CSV")
        return sayings
    }
    
    private func getDefaultSayings() -> [(japanese: String, english: String)] {
        return [
            ("継続は力なり。", "Persistence pays off."),
            ("千里の道も一歩から。", "A journey of a thousand miles begins with a single step."),
            ("ローマは一日にして成らず。", "Rome wasn't built in a day."),
            ("小さな努力が大きな成果を生む。", "Small efforts lead to great results."),
            ("諦めたらそこで試合終了だよ。", "If you give up, the game is over.")
        ]
    }
    
    func getCurrentSaying() -> String {
        let sayings = loadSayings()
        guard !sayings.isEmpty else { 
            return LanguageManager.shared.currentLanguage == .japanese ? "継続は力なり。" : "Persistence pays off."
        }
        
        let currentLanguage = LanguageManager.shared.currentLanguage
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % sayings.count
        
        let selectedSaying = sayings[index]
        
        // Return saying based on current language
        return currentLanguage == .japanese ? selectedSaying.japanese : selectedSaying.english
    }
    
    // MARK: - Debug Methods
    
    func debugFilePaths() {
        print("FileBasedConfigManager Debug:")
        print("Project Directory: \(getProjectDirectoryPath() ?? "nil")")
        print("Keywords File: \(getKeywordsFilePath() ?? "nil")")
        print("Sayings File: \(getSayingsFilePath() ?? "nil")")
        
        if let keywordsPath = getKeywordsFilePath() {
            print("Keywords file exists: \(FileManager.default.fileExists(atPath: keywordsPath))")
        }
        
        if let sayingsPath = getSayingsFilePath() {
            print("Sayings file exists: \(FileManager.default.fileExists(atPath: sayingsPath))")
        }
    }
}