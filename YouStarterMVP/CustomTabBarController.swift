//
//  CustomTabBarController.swift
//  YouStarterMVP
//
//  Enhanced tab bar with LINE-like selection effects
//

import UIKit

class CustomTabBarController: UITabBarController {
    private var tabBarButtonViews: [UIView] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupEnhancedTabBarEffect()
        
        // 言語変更時にタブタイトルを更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateTabTitles),
            name: NSNotification.Name("LanguageChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateTabTitles() {
        // タブタイトルを現在の言語に更新
        guard let viewControllers = viewControllers else { return }
        
        for (index, vc) in viewControllers.enumerated() {
            let newTitle: String
            switch index {
            case 0: // Home
                newTitle = LanguageManager.shared.localizedString(for: "tab_home")
            case 1: // Results
                newTitle = LanguageManager.shared.localizedString(for: "tab_results")
            case 2: // Challenge
                newTitle = LanguageManager.shared.localizedString(for: "tab_challenge")
            case 3: // Wallet
                newTitle = LanguageManager.shared.localizedString(for: "tab_wallet")
            case 4: // Settings
                newTitle = LanguageManager.shared.localizedString(for: "tab_settings")
            default:
                continue
            }
            
            // Update both tab bar item title and view controller title
            vc.tabBarItem.title = newTitle
            
            // Update the navigation controller's root view controller title if needed
            if let navController = vc as? UINavigationController {
                navController.topViewController?.title = newTitle
            } else {
                vc.title = newTitle
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Cache tab bar button views after layout
        cacheTabBarButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 初回表示時にタブタイトルを正しい言語で設定
        updateTabTitles()
    }
    
    private func setupEnhancedTabBarEffect() {
        // Set delegate to handle selection changes
        self.delegate = self
        
        // Initial setup for tab bar items
        updateTabBarItemAppearance()
    }
    
    private func cacheTabBarButtons() {
        // Find all UITabBarButton views (they are subviews of UITabBar)
        tabBarButtonViews = tabBar.subviews.compactMap { subview in
            if String(describing: type(of: subview)).contains("UITabBarButton") {
                return subview
            }
            return nil
        }.sorted { $0.frame.minX < $1.frame.minX } // Sort by X position
    }
    
    private func updateTabBarItemAppearance() {
        guard let items = tabBar.items else { return }
        
        // Reset all tabs to normal size first
        for (index, _) in items.enumerated() {
            if index < tabBarButtonViews.count {
                let tabButton = tabBarButtonViews[index]
                if index != selectedIndex {
                    // Reset non-selected tabs
                    UIView.animate(withDuration: 0.2) {
                        tabButton.transform = CGAffineTransform.identity
                    }
                }
            }
        }
        
        // Make selected tab larger and maintain the size
        if selectedIndex < tabBarButtonViews.count {
            let selectedTabButton = tabBarButtonViews[selectedIndex]
            UIView.animate(withDuration: 0.2) {
                selectedTabButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            }
        }
        
        // Update image insets for visual enhancement
        for (index, item) in items.enumerated() {
            if index == selectedIndex {
                // Selected tab - slightly adjust positioning
                item.imageInsets = UIEdgeInsets(top: -1, left: 0, bottom: 1, right: 0)
                item.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 1)
            } else {
                // Unselected tabs - normal positioning
                item.imageInsets = UIEdgeInsets.zero
                item.titlePositionAdjustment = UIOffset.zero
            }
        }
    }
}

// MARK: - UITabBarControllerDelegate
extension CustomTabBarController: UITabBarControllerDelegate {
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // Update appearance when tab selection changes
        updateTabBarItemAppearance()
        
        // Force update tab titles to prevent language reversion
        updateTabTitles()
        
        // Add subtle animation effect
        if let selectedIndex = tabBarController.viewControllers?.firstIndex(of: viewController),
           let tabBarItems = tabBarController.tabBar.items,
           selectedIndex < tabBarItems.count {
            
            // Create a subtle scale animation for the selected tab
            animateTabSelection(at: selectedIndex)
        }
    }
    
    private func animateTabSelection(at index: Int) {
        guard index < tabBarButtonViews.count else { return }
        
        let selectedTabButton = tabBarButtonViews[index]
        
        // Quick bounce effect when tapped, then maintain larger size
        UIView.animate(withDuration: 0.1, animations: {
            selectedTabButton.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                // End up slightly larger than normal (maintained size)
                selectedTabButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            }
        }
    }
}