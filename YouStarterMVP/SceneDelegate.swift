// SceneDelegate.swift

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
      _ scene: UIScene,
      willConnectTo session: UISceneSession,
      options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)

        // Home
        let homeVC = ViewController()
        homeVC.tabBarItem = UITabBarItem(title: LanguageManager.shared.localizedString(for: "tab_home"),
                                         image: createEmojiImage("🏠", size: CGSize(width: 28, height: 28)),
                                         tag: 0)
        homeVC.tabBarItem.selectedImage = createEmojiImage("🏡", size: CGSize(width: 28, height: 28)) // Filled house
        let homeNav = UINavigationController(rootViewController: homeVC)

        // Money Bag (New)
        let moneyBagVC = MoneyBagViewController()
        moneyBagVC.tabBarItem = UITabBarItem(title: LanguageManager.shared.localizedString(for: "tab_results"),
                                             image: createEmojiImage("💰", size: CGSize(width: 28, height: 28)),
                                             tag: 1)
        moneyBagVC.tabBarItem.selectedImage = createEmojiImage("💎", size: CGSize(width: 28, height: 28)) // Diamond for success

        // Profile/Challenge (renamed and repositioned)
        let profileVC = ProfileViewController()
        profileVC.tabBarItem = UITabBarItem(title: LanguageManager.shared.localizedString(for: "tab_challenge"),
                                            image: createEmojiImage("🔥", size: CGSize(width: 28, height: 28)),
                                            tag: 2)
        profileVC.tabBarItem.selectedImage = createEmojiImage("⚡", size: CGSize(width: 28, height: 28)) // Lightning for active challenge

        // Wallet (moved to position 3)
        let walletVC = WalletViewController()
        walletVC.tabBarItem = UITabBarItem(title: LanguageManager.shared.localizedString(for: "tab_wallet"),
                                           image: createEmojiImage("💳", size: CGSize(width: 28, height: 28)),
                                           tag: 3)
        walletVC.tabBarItem.selectedImage = createEmojiImage("💵", size: CGSize(width: 28, height: 28)) // Money bills for active wallet

        // Settings
        let settingsVC = SettingsViewController()
        settingsVC.tabBarItem = UITabBarItem(title: LanguageManager.shared.localizedString(for: "tab_settings"),
                                             image: createEmojiImage("⚙️", size: CGSize(width: 28, height: 28)),
                                             tag: 4)
        settingsVC.tabBarItem.selectedImage = createEmojiImage("🛠️", size: CGSize(width: 28, height: 28)) // Tools for active settings

        // タブバーに５つセット (order changed: Home, Results, Challenge, Wallet, Settings)
        let tabBar = CustomTabBarController()
        tabBar.viewControllers = [homeNav, moneyBagVC, profileVC, walletVC, settingsVC]
        
        // Configure tab bar appearance with reversed colors (white background, red text)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .white
        
        // Normal state (unselected) - larger, semi-transparent
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemRed.withAlphaComponent(0.6),
            .font: UIFont.systemFont(ofSize: 12)
        ]
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemRed.withAlphaComponent(0.6)
        
        // Selected state - larger, full opacity
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemRed,
            .font: UIFont.boldSystemFont(ofSize: 14)
        ]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .systemRed
        
        // Remove default selection indicator
        tabBarAppearance.selectionIndicatorTintColor = .clear
        
        tabBar.tabBar.standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            tabBar.tabBar.scrollEdgeAppearance = tabBarAppearance
        }
        
        // Enhanced selection visual feedback
        tabBar.tabBar.tintColor = .systemRed
        tabBar.tabBar.unselectedItemTintColor = UIColor.systemRed.withAlphaComponent(0.6)

        window?.rootViewController = tabBar
        window?.makeKeyAndVisible()

        // Check if app was restarted due to language change
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "isLanguageChangeRestart") {
            print("SceneDelegate: 言語変更による再起動を検出しました")
            defaults.removeObject(forKey: "isLanguageChangeRestart")
            defaults.synchronize()
            
            // Show a brief confirmation that language has been changed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let topVC = self.getTopViewController() {
                    let alert = UIAlertController(
                        title: LanguageManager.shared.localizedString(for: "language_changed_title"),
                        message: LanguageManager.shared.localizedString(for: "settings_saved_message"),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
                    topVC.present(alert, animated: true)
                }
            }
        }

        // 通知の初期化は従来通り
        NotificationManager.shared.requestAuthorization()
        if let h = defaults.string(forKey: "alarmHour"),
           let m = defaults.string(forKey: "alarmMinute"),
           let hour = Int(h), let minute = Int(m) {
            NotificationManager.shared.scheduleDailyAlarm(hour: hour, minute: minute)
        } else {
            NotificationManager.shared.scheduleDailyAlarm(hour: 7, minute: 0)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Sceneがディスコネクトされた時（タスクキル時）
        // Called as the scene is being released by the system.
        print("SceneDelegate: Scene disconnected - app was task killed")
        
        // タスクキル時に即座に通知をスケジュール
        NotificationManager.shared.scheduleBackgroundNotification()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Sceneがアクティブになった時（フォアグラウンドから復帰時）
        // Called when the scene has moved from an inactive state to an active state.
        print("SceneDelegate: Scene became active - canceling background notifications")
        
        // アプリが復帰したのでバックグラウンド通知をキャンセル
        NotificationManager.shared.cancelBackgroundNotifications()
        
        // 通知からの起動かどうかチェックして動画再生
        checkAndHandleNotificationLaunch()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Sceneが非アクティブになる時（電話着信、Control Center表示等）
        // Called when the scene will move from an active state to an inactive state.
        print("SceneDelegate: Scene will resign active")
        // バックグラウンド通知はスケジュールしない（一時的な非アクティブ状態のため）
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Sceneがフォアグラウンドに入る時
        // Called as the scene transitions from the background to the foreground.
        print("SceneDelegate: Scene will enter foreground - app resumed from background")
        
        // バックグラウンド通知はキャンセルしない（タスクキル通知と区別するため）
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Sceneがバックグラウンドに入った時
        // Called as the scene transitions from the foreground to the background.
        print("SceneDelegate: Scene entered background - no notification scheduled")
        
        // バックグラウンド移行では通知をスケジュールしない
        // タスクキル時のみsceneDidDisconnectで通知
    }
    
    // Helper function to create emoji images for tab bar items
    private func createEmojiImage(_ emoji: String, size: CGSize) -> UIImage? {
        let font = UIFont.systemFont(ofSize: size.width * 0.8) // Slightly smaller than the size for better fit
        let attributes = [NSAttributedString.Key.font: font]
        let textSize = emoji.size(withAttributes: attributes)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            emoji.draw(in: rect, withAttributes: attributes)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTopViewController() -> UIViewController? {
        guard let window = window,
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        
        if let tabBarController = topController as? UITabBarController,
           let selectedController = tabBarController.selectedViewController {
            if let navController = selectedController as? UINavigationController {
                return navController.topViewController
            }
            return selectedController
        }
        
        if let navController = topController as? UINavigationController {
            return navController.topViewController
        }
        
        return topController
    }
    
    // MARK: - Notification Launch Handling
    
    private func checkAndHandleNotificationLaunch() {
        // 通知からの起動かどうかは UserDefaults で管理
        let wasLaunchedFromNotification = UserDefaults.standard.bool(forKey: "wasLaunchedFromNotification")
        
        if wasLaunchedFromNotification {
            print("SceneDelegate: 通知からの起動を検知、動画再生を開始")
            
            // フラグをリセット
            UserDefaults.standard.set(false, forKey: "wasLaunchedFromNotification")
            
            // 動画再生処理
            guard let tabBarController = window?.rootViewController as? UITabBarController,
                  let navigationController = tabBarController.viewControllers?.first as? UINavigationController,
                  let homeViewController = navigationController.viewControllers.first as? ViewController else {
                print("SceneDelegate: HomeViewControllerが見つかりません")
                return
            }
            
            // ホームタブに切り替え
            tabBarController.selectedIndex = 0
            
            // 動画再生
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                homeViewController.loadTodayForced()
            }
        }
    }
}

