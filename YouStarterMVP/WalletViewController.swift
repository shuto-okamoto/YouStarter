// WalletViewController.swift
// YouStarterMVP

import UIKit

final class WalletViewController: UIViewController, VideoManagerDelegate {
    // MARK: UI Elements
    private let statusLabel    = UILabel()
    private let depositControl = UISegmentedControl(items: [
        LanguageManager.shared.formatCurrency(yenAmount: 1000),
        LanguageManager.shared.formatCurrency(yenAmount: 5000), 
        LanguageManager.shared.formatCurrency(yenAmount: 10000)
    ])
    private let depositButton  = UIButton(type: .system)
    private let restoreButton  = UIButton(type: .system)

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "tab_wallet")
        view.backgroundColor = .systemBackground

        // Set up VideoManager delegate (fallback for other tabs)
        if VideoManager.shared.delegate == nil {
            VideoManager.shared.delegate = self
        }

        setupUI()
        setupActions()

        // デフォルト選択と初回UI更新
        depositControl.selectedSegmentIndex = 0
        segmentChanged(depositControl)
        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: UI Setup
    private func setupUI() {
        [statusLabel, depositControl, depositButton, restoreButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        depositButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        restoreButton.setTitle(LanguageManager.shared.localizedString(for: "wallet_restore_purchases"), for: .normal)


        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            depositControl.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 40),
            depositControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            depositButton.topAnchor.constraint(equalTo: depositControl.bottomAnchor, constant: 20),
            depositButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            restoreButton.topAnchor.constraint(equalTo: depositButton.bottomAnchor, constant: 20),
            restoreButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: Actions Setup
    private func setupActions() {
        depositControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        depositButton.addTarget(self, action: #selector(depositTapped), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateUI),
            name: .iapRestored,
            object: nil
        )
    }

    // MARK: - Actions
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        let titles = ["¥1,000", "¥5,000", "¥10,000"]
        let title = titles[sender.selectedSegmentIndex]
        depositButton.setTitle(String(format: LanguageManager.shared.localizedString(for: "wallet_purchase_credits_amount"), title), for: .normal)
        depositButton.isHidden = false
        depositButton.isEnabled = true
    }

    @objc private func depositTapped() {
        let productIDs: [ProductID] = [.token1000, .token5000, .token10000]
        let selected = productIDs[depositControl.selectedSegmentIndex]
        IAPManager.shared.purchase(selected)
    }

    @objc private func restoreTapped() {
        IAPManager.shared.restorePurchases()
    }


    // MARK: - UI Update
    @objc private func updateUI() {
        statusLabel.text = String(format: LanguageManager.shared.localizedString(for: "wallet_current_balance"), IAPManager.shared.getTokenBalance())
        depositButton.setTitle(LanguageManager.shared.localizedString(for: "wallet_purchase_credits"), for: .normal)
        depositButton.isHidden = false
        depositButton.isEnabled = true

        segmentChanged(depositControl)
    }
    
    // MARK: - VideoManagerDelegate
    func videoManager(_ manager: VideoManager, didUpdateMinimizedState isMinimized: Bool) {
        // No specific UI updates needed in Wallet tab
    }
    
    func videoManager(_ manager: VideoManager, didCompleteVideo duration: TimeInterval) {
        // Video completion handling will be done by ViewController
    }
    
    func videoManager(_ manager: VideoManager, didPlayFor5Minutes: Void) {
        // 5-minute playback handling will be done by ViewController
    }
    
    func videoManager(_ manager: VideoManager, shouldSwitchToHomeTab: Void) {
        // Switch to Home tab when video is maximized
        DispatchQueue.main.async {
            self.tabBarController?.selectedIndex = 0
        }
    }
    
    func videoManager(_ manager: VideoManager, didStopVideo: Void) {
        // No specific action needed in Wallet tab
    }
}
