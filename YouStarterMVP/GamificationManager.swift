//
//  GamificationManager.swift
//  YouStarterMVP
//
//  Created by 岡本秀斗 on 2025/06/XX.
//

import Foundation

/// 継続日数（Streak）やXPを管理するシングルトン
class GamificationManager {

    static let shared = GamificationManager()
    private let defaults = UserDefaults.standard

    private init() { }

    // MARK: - Streak

    /// 最終視聴日 (yyyy-MM-dd の文字列)
    private var lastWatchDate: String? {
        get { defaults.string(forKey: "lastWatchDate") }
        set { defaults.set(newValue, forKey: "lastWatchDate") }
    }

    /// 連続日数
    var streakCount: Int {
        get { defaults.integer(forKey: "streakCount") }
        set { defaults.set(newValue, forKey: "streakCount") }
    }

    /// 今日の視聴を記録し、Streakを更新
    func recordWatchToday() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        if lastWatchDate == today {
            // 既に記録済み
            return
        }

        if let last = lastWatchDate,
           let lastDate = formatter.date(from: last),
           Calendar.current.isDate(lastDate, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date())!) {
            // 昨日も視聴していれば++
            streakCount += 1
        } else {
            // 途切れていれば1から再スタート
            streakCount = 1
        }

        lastWatchDate = today
    }

    // MARK: - XP & Level

    /// 合計経験値
    var xp: Int {
        get { defaults.integer(forKey: "xp") }
        set { defaults.set(newValue, forKey: "xp") }
    }

    /// 現在のレベル算出 (例: 100xpごとに1レベル)
    var level: Int {
        return xp / 100 + 1
    }

    /// XP を追加
    func addXP(_ points: Int) {
        xp += points
    }

    // MARK: - Missions

    struct Mission {
        let id: String
        let title: String
        let goal: Int  // 例: 本数 or 回数
    }

    /// 定義しておくミッション一覧
    let missions: [Mission] = [
        Mission(id: "weekly_watch", title: "今週5本視聴", goal: 5),
        Mission(id: "keyword_use",   title: "キーワード再生1回", goal: 1),
        Mission(id: "channel_use",   title: "チャンネル再生1回", goal: 1),
    ]

    /// ミッション進捗保存用キー
    private func progressKey(for id: String) -> String { "mission_\(id)_progress" }

    /// ミッション進捗取得
    func progress(of mission: Mission) -> Int {
        return defaults.integer(forKey: progressKey(for: mission.id))
    }

    /// ミッションを1増やす
    func incrementProgress(for mission: Mission) {
        let key = progressKey(for: mission.id)
        defaults.set(progress(of: mission) + 1, forKey: key)
    }

    /// ミッション完了判定
    func isCompleted(_ mission: Mission) -> Bool {
        return progress(of: mission) >= mission.goal
    }
}
