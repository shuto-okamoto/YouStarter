// File: VideoSelector.swift
// YouStarterMVP
// Updated to robustly extract video ID from URL or ID string

import Foundation

struct VideoSelector {

    /// おすすめ動画のみ（外部ファイルからキーワード取得）
    static func getVideoID(completion: @escaping (String) -> Void) {
        let keywords = FileBasedConfigManager.shared.loadKeywords()
        guard !keywords.isEmpty else {
            print("VideoSelector: キーワードが見つかりません")
            completion("")
            return
        }
        
        // Try multiple keywords as fallback
        searchWithFallbackKeywords(keywords: keywords, attemptIndex: 0, completion: completion)
    }

    // MARK: - Admin Config (削除済み - キーワードベースに移行)

    // MARK: - Fallback Video List
    private static func defaultDailyVideoID() -> String {
        // Return empty string - no hardcoded fallbacks, rely only on keyword search
        return ""
    }

    // MARK: - Video ID Extraction
    /// URL または生の ID 文字列から YouTube 動画ID (11文字) を抽出
    static func extractVideoID(from raw: String) -> String? {
        guard !raw.isEmpty else { return nil }
        // Try as URL
        if let url = URL(string: raw), let host = url.host {
            if host.contains("youtu.be") {
                let id = url.lastPathComponent
                return id.count == 11 ? id : nil
            }
            if host.contains("youtube.com") {
                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if let v = comps?.queryItems?.first(where: { $0.name == "v" })?.value,
                   v.count == 11 {
                    return v
                }
                // handle embed URLs /shorts etc.
                let pathComp = url.pathComponents.last ?? ""
                return pathComp.count == 11 ? pathComp : nil
            }
        }
        // Fallback: raw itself if it's 11-char ID
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 11 ? trimmed : nil
    }

    // MARK: - YouTube API
    private static let apiKey = "AIzaSyBsXr_LalDPuKELichMkVKxesK3SRqg_rk"
    
    /// Get YouTube API language code for the current app language
    private static func getYouTubeLanguageCode(for language: LanguageManager.SupportedLanguage) -> String {
        switch language {
        case .japanese:
            return "ja"
        case .english:
            return "en"
        case .chinese:
            return "zh"
        }
    }
    
    /// Get YouTube API region code for the current app language
    private static func getYouTubeRegionCode(for language: LanguageManager.SupportedLanguage) -> String {
        switch language {
        case .japanese:
            return "JP"
        case .english:
            return "US"
        case .chinese:
            return "CN"
        }
    }
    
    /// Search with multiple keyword fallback strategy
    private static func searchWithFallbackKeywords(
        keywords: [(japanese: String, english: String, chinese: String)],
        attemptIndex: Int,
        completion: @escaping (String) -> Void
    ) {
        let maxAttempts = min(keywords.count, 5) // Try up to 5 different keywords
        
        guard attemptIndex < maxAttempts else {
            print("VideoSelector: 全てのキーワードで検索に失敗しました")
            completion("")
            return
        }
        
        // Get keyword based on current day and attempt index
        let currentLanguage = LanguageManager.shared.currentLanguage
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let keywordIndex = (dayOfYear - 1 + attemptIndex) % keywords.count
        let selectedKeyword = keywords[keywordIndex]
        
        let searchKeyword: String
        switch currentLanguage {
        case .japanese:
            searchKeyword = selectedKeyword.japanese
        case .english:
            searchKeyword = selectedKeyword.english
        case .chinese:
            searchKeyword = selectedKeyword.chinese
        }
        
        print("VideoSelector: 試行 \(attemptIndex + 1)/\(maxAttempts) - キーワード: '\(searchKeyword)'")
        
        fetchFirstVideoIDByKeyword(searchKeyword) { videoID in
            if !videoID.isEmpty {
                print("VideoSelector: 成功 - 動画ID: \(videoID) (キーワード: \(searchKeyword))")
                completion(videoID)
            } else {
                print("VideoSelector: 失敗 - キーワード '\(searchKeyword)' で動画が見つかりませんでした。次のキーワードを試行...")
                // Try next keyword
                searchWithFallbackKeywords(keywords: keywords, attemptIndex: attemptIndex + 1, completion: completion)
            }
        }
    }

    private static func fetchFirstVideoIDByKeyword(
        _ keyword: String,
        completion: @escaping (String) -> Void
    ) {
        print("VideoSelector: キーワード '\(keyword)' で動画検索を開始")
        
        // APIキーが設定されていない場合のフォールバック
        if apiKey == "YOUR_API_KEY_HERE" {
            print("VideoSelector: YouTube API キーが設定されていません。フォールバック動画を使用します。")
            let fallbackVideoIDs = ["dQw4w9WgXcQ", "9bZkp7q19f0", "kJQP7kiw5Fk", "fJ9rUzIMcZQ", "qeMFqkcPYcg"]
            
            // Find a video not played in the last 60 days
            for videoID in fallbackVideoIDs {
                if !VideoHistoryManager.shared.isVideoPlayedRecently(videoID) {
                    print("VideoSelector: フォールバック動画を選択: \(videoID)")
                    completion(videoID)
                    return
                }
            }
            
            // If all fallback videos were played recently, use the first one anyway
            let fallbackVideoID = fallbackVideoIDs.first ?? "dQw4w9WgXcQ"
            print("VideoSelector: 全てのフォールバック動画が最近再生済み。強制選択: \(fallbackVideoID)")
            completion(fallbackVideoID)
            return
        }
        
        guard let query = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !query.isEmpty else {
            print("VideoSelector: クエリエンコードに失敗しました")
            completion("")
            return
        }
        
        // Get language-specific parameters
        let currentLanguage = LanguageManager.shared.currentLanguage
        let languageCode = getYouTubeLanguageCode(for: currentLanguage)
        let regionCode = getYouTubeRegionCode(for: currentLanguage)
        
        // Build URL with language parameters - get more results to filter from
        var urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&maxResults=20&order=relevance&q=\(query)&key=\(apiKey)"
        
        // Add language and region parameters
        urlString += "&relevanceLanguage=\(languageCode)"
        urlString += "&regionCode=\(regionCode)"
        
        guard let url = URL(string: urlString) else {
            print("VideoSelector: URL構築に失敗しました")
            completion("")
            return
        }
        
        print("VideoSelector: YouTube API リクエスト URL: \(url)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("VideoSelector: API リクエストエラー: \(error)")
                completion("")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("VideoSelector: API レスポンスコード: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("VideoSelector: レスポンスデータがありません")
                completion("")
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("VideoSelector: JSON パースに失敗しました")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("VideoSelector: レスポンス内容: \(dataString)")
                }
                completion("")
                return
            }
            
            if let errorInfo = json["error"] as? [String: Any] {
                print("VideoSelector: YouTube API エラー: \(errorInfo)")
                completion("")
                return
            }
            
            guard let items = json["items"] as? [[String: Any]] else {
                print("VideoSelector: アイテムが見つかりませんでした")
                completion("")
                return
            }
            
            print("VideoSelector: \(items.count) 件の動画が見つかりました (言語: \(languageCode), 地域: \(regionCode))")
            
            // Extract video IDs for duration filtering
            var candidateVideos: [(id: String, title: String, rank: Int)] = []
            let maxRankToConsider = min(15, items.count) // Consider top 15 for better filtering
            
            for index in 0..<maxRankToConsider {
                let item = items[index]
                if let idDict = item["id"] as? [String: Any],
                   let videoID = idDict["videoId"] as? String,
                   let snippet = item["snippet"] as? [String: Any],
                   let title = snippet["title"] as? String {
                    
                    // Check if this video was played recently (60 days)
                    if !VideoHistoryManager.shared.isVideoPlayedRecently(videoID) {
                        candidateVideos.append((id: videoID, title: title, rank: index + 1))
                    } else {
                        print("VideoSelector: 動画 \(videoID) は最近再生されたためスキップします")
                    }
                }
            }
            
            guard !candidateVideos.isEmpty else {
                print("VideoSelector: 警告 - 履歴フィルタ後に候補動画がありません")
                completion("")
                return
            }
            
            print("VideoSelector: \(candidateVideos.count) 件の候補動画で尺チェックを実行します")
            
            // Check duration for candidate videos
            checkVideoDurations(candidateVideos: candidateVideos, completion: completion)
        }.resume()
    }
    
    /// Check video durations and select first video with 7+ minutes duration
    private static func checkVideoDurations(
        candidateVideos: [(id: String, title: String, rank: Int)],
        completion: @escaping (String) -> Void
    ) {
        let videoIDs = candidateVideos.map { $0.id }
        let videoIDsString = videoIDs.joined(separator: ",")
        
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/videos?part=contentDetails&id=\(videoIDsString)&key=\(apiKey)") else {
            print("VideoSelector: 動画詳細取得URL構築に失敗しました")
            completion("")
            return
        }
        
        print("VideoSelector: 動画詳細取得API リクエスト: \(videoIDs.count) 件")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("VideoSelector: 動画詳細取得エラー: \(error)")
                completion("")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                print("VideoSelector: 動画詳細取得JSONパースエラー")
                completion("")
                return
            }
            
            print("VideoSelector: \(items.count) 件の動画詳細を取得しました")
            
            // Create duration map
            var durationMap: [String: String] = [:]
            for item in items {
                if let videoID = item["id"] as? String,
                   let contentDetails = item["contentDetails"] as? [String: Any],
                   let duration = contentDetails["duration"] as? String {
                    durationMap[videoID] = duration
                }
            }
            
            // Find first video with 7+ minutes duration, considering original ranking
            for candidate in candidateVideos.sorted(by: { $0.rank < $1.rank }) {
                if let durationString = durationMap[candidate.id] {
                    let durationSeconds = parseDuration(durationString)
                    let durationMinutes = durationSeconds / 60
                    
                    print("VideoSelector: 動画 \(candidate.id) (\(candidate.title)) - 尺: \(durationMinutes)分 (ランキング: \(candidate.rank)位)")
                    
                    if durationSeconds >= 420 { // 7 minutes = 420 seconds
                        print("VideoSelector: 7分以上の動画を選択: \(candidate.id) (尺: \(durationMinutes)分)")
                        completion(candidate.id)
                        return
                    } else {
                        print("VideoSelector: 7分未満のためスキップ: \(candidate.id) (尺: \(durationMinutes)分)")
                    }
                } else {
                    print("VideoSelector: 動画 \(candidate.id) の尺情報が取得できませんでした")
                }
            }
            
            print("VideoSelector: 7分以上の動画が見つかりませんでした")
            completion("")
        }.resume()
    }
    
    /// Parse YouTube duration format (PT4M13S) to seconds
    private static func parseDuration(_ duration: String) -> Int {
        // YouTube duration format: PT4M13S (4 minutes 13 seconds)
        // PT1H2M10S (1 hour 2 minutes 10 seconds)
        var totalSeconds = 0
        let pattern = "PT(?:(\\d+)H)?(?:(\\d+)M)?(?:(\\d+)S)?"
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: duration, range: NSRange(duration.startIndex..., in: duration)) {
            
            // Hours
            if let hoursRange = Range(match.range(at: 1), in: duration),
               let hours = Int(duration[hoursRange]) {
                totalSeconds += hours * 3600
            }
            
            // Minutes
            if let minutesRange = Range(match.range(at: 2), in: duration),
               let minutes = Int(duration[minutesRange]) {
                totalSeconds += minutes * 60
            }
            
            // Seconds
            if let secondsRange = Range(match.range(at: 3), in: duration),
               let seconds = Int(duration[secondsRange]) {
                totalSeconds += seconds
            }
        }
        
        return totalSeconds
    }

    private static func fetchLatestVideoIDFromChannel(
        _ channelID: String,
        completion: @escaping (String) -> Void
    ) {
        guard !channelID.isEmpty,
              let url = URL(string: "https://www.googleapis.com/youtube/v3/search?part=snippet&order=date&type=video&channelId=\(channelID)&maxResults=1&key=\(apiKey)")
        else {
            completion("")
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]],
                  let idDict = items.first?["id"] as? [String: Any],
                  let videoID = idDict["videoId"] as? String
            else {
                completion("")
                return
            }
            completion(videoID)
        }.resume()
    }
}
