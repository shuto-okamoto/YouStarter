// ChallengeManager.swift
// YouStarterMVP

import Foundation

/// チャレンジ状態変更の通知名
extension Notification.Name {
    static let challengeStateChanged = Notification.Name("challengeStateChanged")
}

/// 30日間チャレンジの状態を保持する構造体
struct Challenge: Codable {
    var isActive: Bool
    var startDate: Date
    var endDate: Date
    var cost: Int // チャレンジに必要なトークン数
    var isFailed: Bool
    var isCompleted: Bool
    var watchedDates: [Date] // New: 視聴した日付の配列
    var isFailedDate: Date? // New: チャレンジが失敗した日時
    var targetMoneyAmount: Int // New: 目標金額
    var isFirstChallenge: Bool // New: 初回チャレンジかどうか
}

/// 30日間チャレンジを管理するクラス
final class ChallengeManager {
    static let shared = ChallengeManager()

    private let challengeKey = "current30DayChallenge"

    private init() {}

    /// 現在のチャレンジ情報を取得
    var currentChallenge: Challenge? {
        get {
            if let data = UserDefaults.standard.data(forKey: challengeKey) {
                return try? JSONDecoder().decode(Challenge.self, from: data)
            }
            return nil
        }
        set {
            if let challenge = newValue {
                if let data = try? JSONEncoder().encode(challenge) {
                    UserDefaults.standard.set(data, forKey: challengeKey)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: challengeKey)
            }
        }
    }

    /// チャレンジを開始
    func startChallenge(cost: Int, targetMoney: Int) -> Bool {
        let isReactivating = (currentChallenge?.isCompleted == true || currentChallenge?.isFailed == true)
        guard currentChallenge == nil || isReactivating else {
            print("ChallengeManager: 既にアクティブなチャレンジがあります。")
            return false
        }

        // トークンを消費
        guard IAPManager.shared.deductTokens(amount: cost) else {
            print("ChallengeManager: トークンが不足しています。")
            // 以前のチャレンジが完了/失敗状態からの再開で、トークン不足により開始失敗した場合、
            // チャレンジ状態をクリアして「未開始」状態に戻す
            if isReactivating {
                currentChallenge = nil
                print("ChallengeManager: トークン不足のため、以前の完了/失敗チャレンジをクリアしました。")
            }
            return false
        }

        // 新しいチャレンジを開始する前に、以前のチャレンジ状態を完全にクリア
        if isReactivating {
            print("ChallengeManager: 以前のチャレンジ状態をクリアして新しいチャレンジを開始します。")
        }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 30, to: startDate)!
        let newChallenge = Challenge(
            isActive: true,
            startDate: startDate,
            endDate: endDate,
            cost: cost,
            isFailed: false,
            isCompleted: false,
            watchedDates: [],
            isFailedDate: nil,
            targetMoneyAmount: targetMoney,
            isFirstChallenge: !isReactivating
        )
        currentChallenge = newChallenge
        print("ChallengeManager: 30日間チャレンジを開始しました。終了日: \(endDate), 状態: isActive=\(currentChallenge?.isActive ?? false), isFailed=\(currentChallenge?.isFailed ?? false), isCompleted=\(currentChallenge?.isCompleted ?? false)")
        
        // チャレンジ状態変更の通知を送信
        NotificationCenter.default.post(name: .challengeStateChanged, object: nil)
        
        return true
    }

    /// チャレンジを継続（失敗状態から復帰）
    func continueChallenge() -> Bool {
        print("ChallengeManager: continueChallenge called.")
        guard var challenge = currentChallenge, challenge.isFailed else {
            print("ChallengeManager: 継続できるチャレンジがありません、または失敗状態ではありません。")
            return false
        }

        // コンティニューに必要なトークンを消費
        guard IAPManager.shared.deductTokens(amount: challenge.cost) else {
            print("ChallengeManager: コンティニューに必要な覚悟クレジットが不足しています。")
            return false
        }

        challenge.isFailed = false // 失敗状態をリセット
        challenge.isActive = true // アクティブ状態に戻す
        challenge.isFailedDate = nil // 失敗日時をリセット
        // コンティニューした日を視聴済みとして追加
        let today = Calendar.current.startOfDay(for: Date())
        if !challenge.watchedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            challenge.watchedDates.append(today)
        }
        // 期限をリセットするかどうかは要件によるが、今回は失敗状態をリセットするのみ
        // 必要であれば、challenge.endDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())! のように期限を延長することも可能
        currentChallenge = challenge
        print("ChallengeManager: チャレンジを継続しました。現在のチャレンジ状態: isActive=\(challenge.isActive), isFailed=\(challenge.isFailed), isCompleted=\(challenge.isCompleted)")
        return true
    }

    /// チャレンジの進捗日数（視聴済み日数）を取得
    func getCompletedDays() -> Int {
        guard let challenge = currentChallenge else { return 0 }
        let uniqueWatchedDates = Set(challenge.watchedDates.map { Calendar.current.startOfDay(for: $0) })
        return uniqueWatchedDates.count
    }

    /// 今日の動画が視聴済みかどうかを判定
    func hasWatchedToday() -> Bool {
        guard let challenge = currentChallenge else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        return challenge.watchedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) })
    }

    /// 今日の動画視聴を記録
    func recordVideoWatched() {
        guard var challenge = currentChallenge, challenge.isActive && !challenge.isFailed else {
            print("ChallengeManager: アクティブなチャレンジがないか、既に失敗しています。")
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        if !challenge.watchedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: today) }) {
            challenge.watchedDates.append(today)
            currentChallenge = challenge
            print("ChallengeManager: 今日の動画視聴を記録しました。")
        } else {
            print("ChallengeManager: 今日の動画は既に視聴済みです。")
        }
    }

    /// チャレンジの状態をチェック（日次で呼び出すことを想定）
    func checkChallengeStatus() {
        guard var challenge = currentChallenge, challenge.isActive && !challenge.isFailed && !challenge.isCompleted else {
            return // アクティブなチャレンジがないか、既に失敗/完了している場合は何もしない
        }

        let calendar = Calendar.current
        let now = Date()

        // Daily check for missed videos
        // Iterate from startDate up to yesterday (or today if it's past midnight)
        var currentDate = calendar.startOfDay(for: challenge.startDate)
        let today = calendar.startOfDay(for: now)

        while currentDate < today { // Check all past days up to yesterday
            let isWatched = challenge.watchedDates.contains(where: { calendar.isDate($0, inSameDayAs: currentDate) })

            // 初回チャレンジの初日のみ23:59まで猶予
            if challenge.isFirstChallenge && calendar.isDate(currentDate, inSameDayAs: challenge.startDate) {
                let endOfFirstDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: challenge.startDate)!
                if now < endOfFirstDay { // まだ初日の23:59を過ぎていない場合はスキップ
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)! // Move to the next day
                    continue
                }
            }

            if !isWatched {
                // This day was missed. Mark challenge as failed.
                challenge.isFailed = true
                challenge.isActive = false
                challenge.isFailedDate = currentDate // Record the date of failure
                currentChallenge = challenge
                print("ChallengeManager: 30日間チャレンジが動画視聴未達成により失敗しました。日付: \(currentDate), 状態: isActive=\(challenge.isActive), isFailed=\(challenge.isFailed), isCompleted=\(challenge.isCompleted)")
                // Trigger failure notification here
                NotificationManager.shared.scheduleFailureNotification()
                return // Challenge failed, no need to check further
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)! // Move to the next day
        }

        // Check for automatic completion on 30 days achievement
        let completedDays = getCompletedDays()
        if completedDays >= 30 {
            // 30日達成時の自動完了
            challenge.isCompleted = true
            challenge.isActive = false
            currentChallenge = challenge
            
            // トークンを返金
            IAPManager.shared.addTokens(amount: challenge.cost)
            
            print("ChallengeManager: 30日間チャレンジを自動完了しました。トークンを返金しました。完了日数: \(completedDays)")
            
            // チャレンジ状態変更の通知を送信
            NotificationCenter.default.post(name: .challengeStateChanged, object: nil)
            return
        }
        
        // Original check for overall challenge end date
        if now > challenge.endDate {
            challenge.isFailed = true
            challenge.isActive = false // 期限切れで失敗
            challenge.isFailedDate = now // 失敗日時を記録
            currentChallenge = challenge
            print("ChallengeManager: 30日間チャレンジが期限切れにより失敗しました。")
            // Trigger failure notification here
            NotificationManager.shared.scheduleFailureNotification()
        }
    }

    
    /// チャレンジをリセット（新しいチャレンジを開始するためにクリア）
    func resetChallenge() {
        currentChallenge = nil
        print("ChallengeManager: チャレンジ状態をリセットしました。")
        
        // チャレンジ状態変更の通知を送信
        NotificationCenter.default.post(name: .challengeStateChanged, object: nil)
    }
    
    /// 失敗したチャレンジが次の日になったら自動的にリセット
    func checkAndResetFailedChallenge() {
        guard let challenge = currentChallenge, challenge.isFailed else { return }
        
        // 失敗日から1日以上経過したかチェック
        if let failedDate = challenge.isFailedDate {
            // 国・地域設定に基づくタイムゾーンでカレンダーを設定
            let calendar = getCalendarWithUserTimeZone()
            let now = Date()
            
            // 失敗日の次の日の00:00を計算（ユーザーのタイムゾーン基準）
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: failedDate))!
            
            if now >= nextDay {
                print("ChallengeManager: 失敗したチャレンジが次の日になったため状態をリセットします。")
                print("ChallengeManager: 失敗日時: \(failedDate), 次の日: \(nextDay), 現在時刻: \(now)")
                
                // UI状態を完全にリセット
                resetChallengeAndUI()
            }
        }
    }
    
    /// 国・地域設定に基づくタイムゾーンでカレンダーを取得
    private func getCalendarWithUserTimeZone() -> Calendar {
        var calendar = Calendar.current
        
        // 設定画面で選択された国・地域に基づくタイムゾーンを適用
        let defaults = UserDefaults.standard
        if let countryLocale = defaults.string(forKey: "selectedCountryLocale") {
            // ロケールからタイムゾーンをマッピング
            let timeZoneMapping: [String: String] = [
                "ja_JP": "Asia/Tokyo",
                "en_US": "America/New_York",
                "zh_CN": "Asia/Shanghai",
                "en_GB": "Europe/London",
                "de_DE": "Europe/Berlin",
                "fr_FR": "Europe/Paris",
                "ko_KR": "Asia/Seoul",
                "en_AU": "Australia/Sydney",
                "en_CA": "America/Toronto",
                "pt_BR": "America/Sao_Paulo"
            ]
            
            if let timeZoneIdentifier = timeZoneMapping[countryLocale],
               let timeZone = TimeZone(identifier: timeZoneIdentifier) {
                calendar.timeZone = timeZone
                print("ChallengeManager: タイムゾーンを設定: \(timeZoneIdentifier) (ロケール: \(countryLocale))")
            }
        }
        
        return calendar
    }
    
    /// チャレンジとUIを完全リセット
    private func resetChallengeAndUI() {
        // チャレンジ状態をクリア
        currentChallenge = nil
        print("ChallengeManager: チャレンジ状態とUIを完全リセットしました。")
        
        // UI更新のための通知を送信
        DispatchQueue.main.async {
            // チャレンジ状態変更の通知を送信
            NotificationCenter.default.post(name: .challengeStateChanged, object: nil)
            
            // 追加でUI更新通知も送信
            NotificationCenter.default.post(name: NSNotification.Name("ChallengeUIReset"), object: nil)
            
            print("ChallengeManager: UI更新通知を送信しました")
        }
    }
    
    /// 動画再生開始時刻を記録
    func recordVideoStartTime() {
        let defaults = UserDefaults.standard
        let now = Date()
        
        // 前回記録された開始時刻を取得
        if let lastStartTime = defaults.object(forKey: "todayVideoStartTime") as? Date {
            let calendar = Calendar.current
            // 前回と違う日なら記録をクリア
            if !calendar.isDate(lastStartTime, inSameDayAs: now) {
                defaults.removeObject(forKey: "todayVideoStartTime")
                print("ChallengeManager: 前日の動画開始時刻記録をクリアしました")
            }
        }
        
        defaults.set(now, forKey: "todayVideoStartTime")
        print("ChallengeManager: 今日の動画再生開始時刻を記録しました: \(now)")
    }
    
    /// 指定時刻からの自動失敗判定をチェック
    func checkScheduledTimeFailure() {
        guard var challenge = currentChallenge, challenge.isActive && !challenge.isFailed && !challenge.isCompleted else {
            return
        }
        
        // 今日の動画視聴が既に完了している場合はチェックしない
        if hasWatchedToday() {
            return
        }
        
        let defaults = UserDefaults.standard
        guard let savedTime = defaults.object(forKey: "playTime") as? Date else {
            print("ChallengeManager: 再生時間が設定されていないため自動失敗判定をスキップします")
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // 初回チャレンジの初日は23:59まで猶予（指定時刻制限なし）
        if challenge.isFirstChallenge && calendar.isDate(today, inSameDayAs: challenge.startDate) {
            print("ChallengeManager: 初回チャレンジの初日のため指定時刻制限をスキップします")
            return
        }
        
        // 今日の指定時刻を計算
        let timeComponents = calendar.dateComponents([.hour, .minute], from: savedTime)
        guard let todayScheduledTime = calendar.date(bySettingHour: timeComponents.hour ?? 19, 
                                                   minute: timeComponents.minute ?? 0, 
                                                   second: 0, 
                                                   of: today) else {
            return
        }
        
        // 指定時刻+5分後を計算（動画開始の締切時刻）
        let videoStartDeadline = calendar.date(byAdding: .minute, value: 5, to: todayScheduledTime)!
        
        // 今日の動画開始時刻を取得
        let todayVideoStartTime = defaults.object(forKey: "todayVideoStartTime") as? Date
        
        // 現在時刻が指定時刻+5分後を過ぎている場合の処理
        if now > videoStartDeadline {
            // 動画開始時刻が記録されていない、または指定時刻+5分後より後に開始した場合は失敗
            if todayVideoStartTime == nil || todayVideoStartTime! > videoStartDeadline {
                challenge.isFailed = true
                challenge.isActive = false
                challenge.isFailedDate = now
                currentChallenge = challenge
                
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let scheduledTimeStr = formatter.string(from: todayScheduledTime)
                let deadlineStr = formatter.string(from: videoStartDeadline)
                
                if let startTime = todayVideoStartTime {
                    let startTimeStr = formatter.string(from: startTime)
                    print("ChallengeManager: 動画開始が遅すぎたため失敗しました。指定時刻: \(scheduledTimeStr), 開始締切: \(deadlineStr), 実際の開始時刻: \(startTimeStr)")
                } else {
                    print("ChallengeManager: 指定時刻制限内に動画が開始されなかったため失敗しました。指定時刻: \(scheduledTimeStr), 開始締切: \(deadlineStr)")
                }
                
                // 失敗通知を送信
                NotificationManager.shared.scheduleFailureNotification()
                
                // チャレンジ状態変更の通知を送信
                NotificationCenter.default.post(name: .challengeStateChanged, object: nil)
            }
        }
    }
    
    /// 5分視聴不足の警告通知をチェック（12時、15時、18時、21時）
    func checkDailyWatchingProgress() {
        guard let challenge = currentChallenge, challenge.isActive && !challenge.isFailed && !challenge.isCompleted else {
            return
        }
        
        // 今日の動画視聴が既に完了している場合は通知しない
        if hasWatchedToday() {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        
        // 12時、15時、18時、21時の正時のみチェック（分が0-1の間）
        let warningHours = [12, 15, 18, 21]
        guard warningHours.contains(currentHour) && currentMinute <= 1 else {
            return
        }
        
        // 今日が日付変更直前かチェック（23時以降）
        let isNearMidnight = currentHour >= 23
        
        if isNearMidnight || warningHours.contains(currentHour) {
            let title = LanguageManager.shared.localizedString(for: "daily_watch_reminder_title")
            let message = LanguageManager.shared.localizedString(for: "daily_watch_reminder_message")
            
            print("ChallengeManager: 5分視聴不足の警告通知を送信します（\(currentHour)時）")
            
            // 即座に通知を送信
            NotificationManager.shared.scheduleImmediateNotification(title: title, message: message)
        }
    }
}
