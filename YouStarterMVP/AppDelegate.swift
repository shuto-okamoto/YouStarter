//
//  AppDelegate.swift
//  YouStarterMVP
//
//  Created by 岡本秀斗 on 2025/06/21.
//

import UIKit
import UserNotifications
import StoreKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // IAP 製品情報取得開始
        IAPManager.shared.start()

        // 通知デリゲート設定
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // 通知アクション／カテゴリ登録
        setupNotificationCategories()

        // 通知許可リクエスト
        NotificationManager.shared.requestAuthorization()

        // 保存された alarmHour/alarmMinute を読み出し
        let defaults = UserDefaults.standard
        let hour: Int
        let minute: Int
        if let hs = defaults.string(forKey: "alarmHour"),
           let ms = defaults.string(forKey: "alarmMinute"),
           let hh = Int(hs), let mm = Int(ms) {
            hour = hh; minute = mm
        } else {
            hour = 7; minute = 0
        }

        // 通知スケジュール（カテゴリ指定）
        NotificationManager.shared.scheduleDailyAlarm(
            hour: hour,
            minute: minute,
            categoryIdentifier: "DAILY_ALARM"
        )

        // チャレンジの状態をチェック
        ChallengeManager.shared.checkChallengeStatus()

        

        return true
    }

    // フォアグラウンドでもバナー＋音
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    // 通知タップ or アクションタップ
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("AppDelegate: 通知タップ受信 - actionIdentifier: \(response.actionIdentifier), notificationId: \(response.notification.request.identifier)")
        
        // 定刻通知のみ動画再生を実行（タスクキル通知は再生しない）
        if response.actionIdentifier == "PLAY_ACTION"
            || response.notification.request.identifier == "dailyAlarm" {
            
            print("AppDelegate: 定刻通知から動画再生処理を開始")
            
            // SceneDelegate用のフラグを設定
            UserDefaults.standard.set(true, forKey: "wasLaunchedFromNotification")
            
            // 直接処理も試行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.handleVideoPlaybackFromNotification()
            }
        } else if response.notification.request.identifier.hasPrefix("backgroundWarning") {
            print("AppDelegate: タスクキル通知タップ - 動画再生は行わない")
            // タスクキル通知の場合は動画再生を行わず、アプリを開くのみ
        }
        completionHandler()
    }

    // MARK: UISceneSession Lifecycle
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) { }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // アプリがフォアグラウンドになったときにチャレンジの状態をチェック
        ChallengeManager.shared.checkChallengeStatus()
        ChallengeManager.shared.checkAndResetFailedChallenge()
        
        // 通知カテゴリを現在の言語で更新
        setupNotificationCategories()
    }
    
    // applicationWillResignActiveは削除し、SceneDelegateに移行
    
    // MARK: - Notification Categories Setup
    
    private func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        // 現在の言語で通知アクションを作成
        let playActionTitle = LanguageManager.shared.localizedString(for: "notification_play_action")
        
        let playAction = UNNotificationAction(
            identifier: "PLAY_ACTION",
            title: playActionTitle,
            options: [.foreground]
        )
        
        let dailyCategory = UNNotificationCategory(
            identifier: "DAILY_ALARM",
            actions: [playAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([dailyCategory])
        print("AppDelegate: Updated notification categories for language: \(LanguageManager.shared.currentLanguage)")
    }
    
    // MARK: - Video Playback from Notification
    
    private func handleVideoPlaybackFromNotification() {
        print("AppDelegate: handleVideoPlaybackFromNotification 開始")
        
        // アクティブなシーンを探す
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let window = windowScene.windows.first,
              let tabBarController = window.rootViewController as? UITabBarController else {
            print("AppDelegate: TabBarControllerが見つかりません")
            return
        }
        
        print("AppDelegate: TabBarControllerを発見")
        
        // ホームタブに切り替え
        tabBarController.selectedIndex = 0
        
        // ViewControllerを取得
        guard let navigationController = tabBarController.viewControllers?.first as? UINavigationController,
              let homeViewController = navigationController.viewControllers.first as? ViewController else {
            print("AppDelegate: HomeViewControllerが見つかりません")
            return
        }
        
        print("AppDelegate: HomeViewControllerを発見、動画再生を開始")
        
        // 動画再生を実行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            homeViewController.loadTodayForced()
        }
    }
}
