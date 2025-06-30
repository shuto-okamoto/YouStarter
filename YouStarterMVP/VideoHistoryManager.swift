//
//  VideoHistoryManager.swift
//  YouStarterMVP
//
//  Manages video playback history to prevent replaying videos within 60 days
//

import Foundation

class VideoHistoryManager {
    static let shared = VideoHistoryManager()
    
    private let userDefaults = UserDefaults.standard
    private let historyKey = "playedVideoHistory"
    private let maxHistoryDays = 60
    
    private init() {}
    
    // MARK: - History Management
    
    func addVideoToHistory(_ videoID: String) {
        var history = getPlayedVideoHistory()
        let currentDate = Date()
        
        // Add or update the video entry with current date
        history[videoID] = currentDate
        
        // Clean up old entries (older than 60 days)
        cleanupOldHistory(&history)
        
        // Save updated history
        saveHistory(history)
        
        print("VideoHistoryManager: Added video \(videoID) to history")
    }
    
    func isVideoPlayedRecently(_ videoID: String) -> Bool {
        let history = getPlayedVideoHistory()
        
        guard let playedDate = history[videoID] else {
            return false // Video not in history
        }
        
        let daysSincePlay = Calendar.current.dateComponents([.day], from: playedDate, to: Date()).day ?? 0
        let isRecent = daysSincePlay < maxHistoryDays
        
        if isRecent {
            print("VideoHistoryManager: Video \(videoID) was played \(daysSincePlay) days ago - skipping")
        }
        
        return isRecent
    }
    
    func getRecentVideoIDs() -> [String] {
        let history = getPlayedVideoHistory()
        return Array(history.keys)
    }
    
    // MARK: - Private Methods
    
    private func getPlayedVideoHistory() -> [String: Date] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return history
    }
    
    private func saveHistory(_ history: [String: Date]) {
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
    
    private func cleanupOldHistory(_ history: inout [String: Date]) {
        let currentDate = Date()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxHistoryDays, to: currentDate) ?? currentDate
        
        // Remove entries older than 60 days
        history = history.filter { _, playedDate in
            playedDate >= cutoffDate
        }
        
        print("VideoHistoryManager: Cleaned up old history entries")
    }
    
    // MARK: - Debug/Admin Methods
    
    func clearHistory() {
        userDefaults.removeObject(forKey: historyKey)
        print("VideoHistoryManager: Cleared all video history")
    }
    
    func getHistoryCount() -> Int {
        return getPlayedVideoHistory().count
    }
}