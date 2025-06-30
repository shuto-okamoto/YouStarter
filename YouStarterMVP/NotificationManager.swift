import Foundation
import UserNotifications

/// ローカル通知のスケジュール管理と再生期限設定
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}
    
    /// プランごとの期限しきい値（秒）を返す
    private func thresholdInterval() -> TimeInterval {
        switch IAPManager.shared.lastPurchasedProductID() {
        case ProductID.token5000.rawValue: return 10 * 60   // 5000円→10分
        case ProductID.token10000.rawValue: return 5 * 60   // 10000円→5分
        default:                            return 15 * 60       // 1000円→15分
        }
    }
    
    /// 通知の許可をリクエスト
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let e = error { print("🔔 通知許可エラー: \(e)") }
            else           { print("🔔 通知許可結果: \(granted)") }
        }
    }
    
    /**
     毎日指定時刻にローカル通知をスケジュールし、
     同時に基準時刻と再生期限を UserDefaults に保存する
     
     - Parameters:
     - hour: 通知を鳴らす時（24h）
     - minute: 通知を鳴らす分
     - categoryIdentifier: 通知カテゴリーID
     */
    func scheduleDailyAlarm(
        hour: Int,
        minute: Int,
        categoryIdentifier: String = "DAILY_ALARM"
    ) {
        let center = UNUserNotificationCenter.current()
        // 1) 既存の dailyAlarm を取消
        center.removePendingNotificationRequests(withIdentifiers: ["dailyAlarm"])
        
        // 2) 通知コンテンツ
        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.localizedString(for: "daily_notification_title")
        content.body  = LanguageManager.shared.localizedString(for: "daily_notification_body")
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        
        // 3) 毎日トリガー
        var dc = DateComponents()
        dc.hour = hour; dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        
        // 4) 通知登録
        let req = UNNotificationRequest(identifier: "dailyAlarm", content: content, trigger: trigger)
        center.add(req) { error in
            if let e = error { print("🔔 通知登録失敗: \(e)") }
            else           { print("🔔 毎日 \(hour)時\(minute)分 に通知") }
        }
        
        // 5) 基準時刻と期限を保存
        let cal = Calendar.current
        var baseDc = cal.dateComponents([.year, .month, .day], from: Date())
        baseDc.hour = hour; baseDc.minute = minute; baseDc.second = 0
        if let base = cal.date(from: baseDc) {
            let deadline = base.addingTimeInterval(thresholdInterval())
            UserDefaults.standard.set(base,     forKey: "basePlayTime")
            UserDefaults.standard.set(deadline, forKey: "nextPlayDeadline")
            print("▶ 基準時刻: \(base), 期限: \(deadline)")
        }
    }
    
    /// チャレンジ失敗時の通知をスケジュール
    func scheduleFailureNotification() {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.localizedString(for: "mission_failed_title")
        content.body = LanguageManager.shared.localizedString(for: "mission_failed_message")
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil) // Trigger immediately
        center.add(request) { error in
            if let e = error { print("🔔 失敗通知登録失敗: \(e)") }
            else           { print("🔔 失敗通知を送信しました。") }
        }
    }
    
    /// タスクキル時のバックグラウンド通知をスケジュール
    func scheduleBackgroundNotification() {
        let center = UNUserNotificationCenter.current()
        
        // 既存のバックグラウンド通知をキャンセル
        center.removePendingNotificationRequests(withIdentifiers: ["taskKillWarning"])
        
        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.localizedString(for: "task_kill_warning_title")
        content.body = LanguageManager.shared.localizedString(for: "task_kill_warning_message")
        content.sound = .default
        
        // 即座に通知を送信（1秒後）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "taskKillWarning", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let e = error {
                print("🔔 タスクキル警告通知登録失敗: \(e)")
            } else {
                print("🔔 タスクキル警告通知をスケジュール（5秒後）")
            }
        }
    }
    
    /// アプリがフォアグラウンドに復帰したときにバックグラウンド通知をキャンセル
    func cancelBackgroundNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["taskKillWarning"])
        print("🔔 タスクキル警告通知をキャンセルしました")
    }
    
    /// 即座に通知を送信（1秒後に配信）
    func scheduleImmediateNotification(title: String, message: String, identifier: String = "immediateNotification") {
        let center = UNUserNotificationCenter.current()
        
        // 既存の即座通知をキャンセル
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        // 1秒後に通知を送信
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let e = error {
                print("🔔 即座通知登録失敗: \(e)")
            } else {
                print("🔔 即座通知をスケジュール: \(title)")
            }
        }
    }
}
