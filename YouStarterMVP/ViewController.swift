//
//  ViewController.swift
//  YouStarterMVP
//
//  Created by YourName on 2025/06/28.
//

import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, VideoManagerDelegate {

    private var webView: WKWebView!
    private var spinner: UIActivityIndicatorView!
    private var overlayView: UIView!
    private var waitingLabel: UILabel!
    private var playNowButton: UIButton!
    private var playTimer: Timer?

    // Challenge UI elements
    private var challengeCostSegmentedControl: UISegmentedControl!
    private var startChallengeButton: UIButton!
    // New button for starting challenge flow
    private var newChallengeEntryButton: UIButton!
    private var challengeIntroLabel: UILabel!

    // For video minimization
    private var panGesture: UIPanGestureRecognizer!
    private var tapGesture: UITapGestureRecognizer!
    private var isMinimized = false
    private var initialWebViewFrame: CGRect = .zero // Initial frame to restore to

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LanguageManager.shared.localizedString(for: "tab_home")
        view.backgroundColor = .systemBackground

        // Set up VideoManager delegate
        VideoManager.shared.delegate = self

        // 設定画面で保存されたときに再チェック
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsDidSave),
            name: .settingsDidSave,
            object: nil
        )
        
        // 言語変更時にUIを更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateLocalization),
            name: NSNotification.Name("LanguageChanged"),
            object: nil
        )
        
        // チャレンジUI完全リセット通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleChallengeUIReset),
            name: NSNotification.Name("ChallengeUIReset"),
            object: nil
        )

        setupOverlay()
        setupSpinner()
        setupWaitingLabel()
        setupPlayNowButton()
        setupWebView()
        setupChallengeStartUI() // This will now set up the new entry button
        setupGestures() // ジェスチャーのセットアップを追加

        // 失敗したチャレンジの次の日リセットチェック
        ChallengeManager.shared.checkAndResetFailedChallenge()
        
        // 自動失敗判定とリマインダーチェック
        ChallengeManager.shared.checkScheduledTimeFailure()
        ChallengeManager.shared.checkDailyWatchingProgress()
        
        resetUI()
        updateChallengeUIState() // Add this line
    }
    
    @objc private func updateLocalization() {
        title = LanguageManager.shared.localizedString(for: "tab_home")
        newChallengeEntryButton.setTitle(LanguageManager.shared.localizedString(for: "challenge_30_days"), for: .normal)
        playNowButton.setTitle(LanguageManager.shared.localizedString(for: "watch_now"), for: .normal)
        updateChallengeUIState() // Update challenge intro text
    }
    
    @objc private func handleChallengeUIReset() {
        print("ViewController: チャレンジUI完全リセット通知を受信しました")
        
        // UIを強制的にチャレンジ前の状態にリセット
        DispatchQueue.main.async {
            self.resetToPreChallengeState()
            self.updateChallengeUIState()
        }
    }
    
    /// UIをチャレンジ前の状態に強制リセット
    private func resetToPreChallengeState() {
        // 動画関連UI要素をリセット
        resetUI()
        
        // チャレンジ関連のUI要素も確実にリセット
        challengeIntroLabel.isHidden = false
        challengeIntroLabel.text = LanguageManager.shared.localizedString(for: "home_intro_text")
        
        newChallengeEntryButton.isHidden = false
        newChallengeEntryButton.setTitle(LanguageManager.shared.localizedString(for: "challenge_30_days"), for: .normal)
        
        // 動画再生関連をクリア
        playTimer?.invalidate()
        playTimer = nil
        
        print("ViewController: UIをチャレンジ前の状態にリセットしました")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateChallengeUIState() // Add this line
        
        // 自動失敗判定とリマインダーチェック
        ChallengeManager.shared.checkScheduledTimeFailure()
        ChallengeManager.shared.checkDailyWatchingProgress()
        
        // Only call checkAndSchedulePlay if no video is currently active
        // This prevents showing "今すぐ見る" while video is playing in minimized state
        if !VideoManager.shared.hasActiveVideo {
            checkAndSchedulePlay()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        playTimer?.invalidate()
        playTimer = nil
    }

    private func setupOverlay() {
        overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor(white: 0, alpha: 0.3)
        overlayView.isHidden = true
        view.addSubview(overlayView)
    }

    private func setupSpinner() {
        spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .systemBlue
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor)
        ])
    }

    private func setupWaitingLabel() {
        waitingLabel = UILabel()
        waitingLabel.textAlignment = .center
        waitingLabel.textColor = .secondaryLabel
        waitingLabel.numberOfLines = 0
        waitingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(waitingLabel)

        challengeIntroLabel = UILabel()
        challengeIntroLabel.textAlignment = .center
        challengeIntroLabel.textColor = .secondaryLabel
        challengeIntroLabel.numberOfLines = 0
        challengeIntroLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(challengeIntroLabel)

        NSLayoutConstraint.activate([
            waitingLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waitingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            waitingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            waitingLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            challengeIntroLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            challengeIntroLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            challengeIntroLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            challengeIntroLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupPlayNowButton() {
        playNowButton = UIButton(type: .system)
        playNowButton.setTitle(LanguageManager.shared.localizedString(for: "watch_now"), for: .normal)
        playNowButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        playNowButton.isHidden = true
        playNowButton.translatesAutoresizingMaskIntoConstraints = false
        playNowButton.addTarget(self, action: #selector(playNowTapped), for: .touchUpInside)
        view.addSubview(playNowButton)
        NSLayoutConstraint.activate([
            playNowButton.topAnchor.constraint(equalTo: challengeIntroLabel.bottomAnchor, constant: 20),
            playNowButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupWebView() {
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "videoPlayer")

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Initialize with full screen frame, and allow direct frame manipulation
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = true // Enable direct frame manipulation
        webView.isHidden = true
        webView.backgroundColor = .clear // 背景を透明に
        webView.isOpaque = false // 不透明度をfalseに
        view.addSubview(webView)
        // No constraints activated here, frame will be managed manually
    }

    private func setupChallengeStartUI() {
        // Remove old segmented control and start button from this setup
        // They will be handled by the newChallengeEntryButton flow

        newChallengeEntryButton = UIButton(type: .system)
        newChallengeEntryButton.setTitle(LanguageManager.shared.localizedString(for: "challenge_30_days"), for: .normal)
        newChallengeEntryButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        newChallengeEntryButton.translatesAutoresizingMaskIntoConstraints = false
        newChallengeEntryButton.addTarget(self, action: #selector(startChallengeFlow), for: .touchUpInside)
        view.addSubview(newChallengeEntryButton)

        NSLayoutConstraint.activate([
            newChallengeEntryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newChallengeEntryButton.topAnchor.constraint(equalTo: challengeIntroLabel.bottomAnchor, constant: 30)
        ])
    }

    private func setupGestures() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        webView.addGestureRecognizer(panGesture)

        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.isEnabled = false // 最初は無効
        webView.addGestureRecognizer(tapGesture)
    }

    private func resetUI() {
        waitingLabel.isHidden = true
        challengeIntroLabel.isHidden = true
        playNowButton.isHidden = true
        newChallengeEntryButton.isHidden = true
        webView.isHidden = true
        overlayView.isHidden = true
        spinner.stopAnimating()
        
        // Ensure webView is maximized when UI is reset
        maximizePlayer(animated: false)
    }

    @objc private func handleSettingsDidSave() {
        // Delay to avoid conflicting with settings alert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.checkAndSchedulePlay()
        }
    }
    
    @objc private func checkAndSchedulePlay() {
        playTimer?.invalidate()
        playTimer = nil

        // Don't show any video UI if video is already playing
        if VideoManager.shared.hasActiveVideo {
            waitingLabel.isHidden = true
            playNowButton.isHidden = true
            return
        }

        // Check if there's an active challenge for full video playback
        let hasActiveChallenge = ChallengeManager.shared.currentChallenge?.isActive == true
        
        // If no active challenge, show scheduled time alert only (free plan behavior)
        guard hasActiveChallenge else {
            showScheduledTimeAlert()
            return
        }

        let defaults = UserDefaults.standard
        guard let savedTime = defaults.object(forKey: "playTime") as? Date else {
            waitingLabel.text = LanguageManager.shared.localizedString(for: "video_time_not_set")
            waitingLabel.isHidden = false
            playNowButton.isHidden = true
            return
        }

        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: savedTime)
        let potentialNextDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime)
        guard let nextDate = potentialNextDate else {
            waitingLabel.text = LanguageManager.shared.localizedString(for: "waiting_for_playback")
            playNowButton.isHidden = true
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let nextStr = formatter.string(from: nextDate)

        // Check if video watched today
        let hasWatchedToday = ChallengeManager.shared.hasWatchedToday()

        if now >= nextDate {
            loadToday()
        } else {
            let alertTitle: String
            let alertMessage: String
            
            alertTitle = LanguageManager.shared.localizedString(for: "waiting_for_scheduled_time")
            alertMessage = String(format: LanguageManager.shared.localizedString(for: "next_playback_time"), nextStr)
            // Set button title based on whether video has been watched today
            playNowButton.setTitle(hasWatchedToday ? LanguageManager.shared.localizedString(for: "watch_again") : LanguageManager.shared.localizedString(for: "watch_now"), for: .normal)
            playNowButton.isHidden = false // Show button

            // Remove playback waiting alerts - no longer needed
            print("ViewController: 再生待機アラートは削除されました - 言語変更のみ設定画面から実行")
            print("ViewController: Playback waiting alerts removed - language change only from settings")

            // UIの状態を更新
            waitingLabel.isHidden = true // Always hide waitingLabel when alert is shown

            let interval = nextDate.timeIntervalSince(now)
            playTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.loadToday()
            }
        }
    }

    @objc private func playNowTapped() {
        playTimer?.invalidate()
        playTimer = nil
        loadToday()
    }
    
    // MARK: - Free Plan Behavior
    private func showScheduledTimeAlert() {
        let defaults = UserDefaults.standard
        guard let savedTime = defaults.object(forKey: "playTime") as? Date else {
            let alert = UIAlertController(
                title: LanguageManager.shared.localizedString(for: "error_title"),
                message: LanguageManager.shared.localizedString(for: "video_time_not_set"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
            present(alert, animated: true)
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeString = formatter.string(from: savedTime)
        
        // Show normal scheduled time alert
        let message = String(format: LanguageManager.shared.localizedString(for: "next_playback_time"), timeString)
        let alert = UIAlertController(
            title: LanguageManager.shared.localizedString(for: "waiting_for_scheduled_time"),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
        
        // Only show alert if no other view controller is being presented
        if self.presentedViewController == nil {
            present(alert, animated: true)
        }
    }

    func loadToday() {
        resetUI()

        // チャレンジが完了している場合は動画再生をスキップ
        if ChallengeManager.shared.currentChallenge?.isCompleted == true {
            print("ChallengeManager: チャレンジが完了しているため動画再生をスキップします。")
            updateChallengeUIState() // Update UI to show challenge completed state
            return
        }
        
        startVideoPlayback()
    }
    
    /// 通知からの強制的な動画再生（無料プランでも再生）
    func loadTodayForced() {
        print("ViewController: loadTodayForced() 呼び出し - 通知からの強制再生")
        resetUI()
        print("ViewController: resetUI完了、startVideoPlaybackを呼び出し")
        startVideoPlayback()
    }
    
    /// 共通の動画再生ロジック
    private func startVideoPlayback() {
        VideoSelector.getVideoID { [weak self] videoID in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("ViewController: 取得した動画ID: '\(videoID)' (長さ: \(videoID.count))")
                
                guard !videoID.isEmpty && videoID.count == 11 else {
                    print("ViewController: 動画IDが無効です - 長さ: \(videoID.count)")
                    let alert = UIAlertController(
                        title: LanguageManager.shared.localizedString(for: "error_title"),
                        message: LanguageManager.shared.localizedString(for: "error_invalid_video_id"),
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
                    self.present(alert, animated: true)
                    return
                }
                self.waitingLabel.isHidden = true
                self.playNowButton.isHidden = true
                self.overlayView.isHidden = false
                self.spinner.startAnimating()
                
                // Check if user has active challenge or tokens for video playback
                let hasActiveChallenge = ChallengeManager.shared.currentChallenge != nil
                let hasTokens = IAPManager.shared.getTokenBalance() > 0
                
                print("ViewController: hasActiveChallenge=\(hasActiveChallenge), hasTokens=\(hasTokens)")
                
                if hasActiveChallenge || hasTokens {
                    // Use VideoManager for cross-tab video playback (paid features)
                    print("ViewController: 有料プランでVideoManagerを使用")
                    if let window = self.view.window {
                        let hasWatchedToday = ChallengeManager.shared.hasWatchedToday()
                        VideoManager.shared.startVideo(videoID: videoID, in: window, isReplay: hasWatchedToday)
                        
                        // Add video to history after starting playback
                        VideoHistoryManager.shared.addVideoToHistory(videoID)
                    }
                } else {
                    // Free plan: play video directly without minimization features
                    print("ViewController: 無料プランで直接再生")
                    self.loadYouTubeVideoForFreePlan(videoID: videoID)
                    
                    // Add video to history after starting playback
                    VideoHistoryManager.shared.addVideoToHistory(videoID)
                }
            }
        }
    }

    // MARK: - Free Plan Video Playback
    
    private func loadYouTubeVideoForFreePlan(videoID: String) {
        // Hide challenge UI elements when video starts playing
        newChallengeEntryButton.isHidden = true
        challengeIntroLabel.isHidden = true
        
        // Calculate frame for video player to fill available space
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        
        // Create frame that uses available space between navigation and tab bar
        let videoFrame = CGRect(
            x: 0,
            y: view.safeAreaInsets.top,
            width: view.bounds.width,
            height: view.bounds.height - view.safeAreaInsets.top - tabBarHeight
        )
        
        webView.frame = videoFrame
        view.addSubview(webView)
        
        // Add close button for free plan
        setupFreePlanCloseButton()
        
        let embedHTML = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; padding: 0; background-color: black; }
                iframe { width: 100%; height: 100vh; border: none; }
            </style>
        </head>
        <body>
            <iframe src="https://www.youtube.com/embed/\(videoID)?autoplay=1&playsinline=1&controls=1" allowfullscreen></iframe>
        </body>
        </html>
        """
        
        webView.loadHTMLString(embedHTML, baseURL: nil)
        overlayView.isHidden = true
        spinner.stopAnimating()
    }
    
    private var freePlanCloseButton: UIButton?
    
    private func setupFreePlanCloseButton() {
        freePlanCloseButton?.removeFromSuperview()
        
        freePlanCloseButton = UIButton(type: .system)
        freePlanCloseButton?.setTitle("×", for: .normal)
        freePlanCloseButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        freePlanCloseButton?.setTitleColor(.white, for: .normal)
        freePlanCloseButton?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        freePlanCloseButton?.layer.cornerRadius = 20
        freePlanCloseButton?.addTarget(self, action: #selector(freePlanCloseButtonTapped), for: .touchUpInside)
        
        let buttonSize: CGFloat = 40
        freePlanCloseButton?.frame = CGRect(
            x: view.bounds.width - buttonSize - 20,
            y: view.safeAreaInsets.top + 20,
            width: buttonSize,
            height: buttonSize
        )
        
        view.addSubview(freePlanCloseButton!)
    }
    
    @objc private func freePlanCloseButtonTapped() {
        let alert = UIAlertController(
            title: LanguageManager.shared.localizedString(for: "stop_video_confirmation_title"),
            message: LanguageManager.shared.localizedString(for: "stop_video_confirmation_message"),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: LanguageManager.shared.localizedString(for: "cancel"),
            style: .cancel
        ))
        
        alert.addAction(UIAlertAction(
            title: LanguageManager.shared.localizedString(for: "stop_video"),
            style: .destructive,
            handler: { _ in
                self.stopFreePlanVideo()
            }
        ))
        
        present(alert, animated: true)
    }
    
    private func stopFreePlanVideo() {
        webView.removeFromSuperview()
        freePlanCloseButton?.removeFromSuperview()
        freePlanCloseButton = nil
        
        // Show challenge UI elements again
        newChallengeEntryButton.isHidden = false
        challengeIntroLabel.isHidden = false
        
        resetUI()
    }

    private func loadYouTubeVideo(videoID: String) {
        // Hide challenge UI elements when video starts playing
        newChallengeEntryButton.isHidden = true
        challengeIntroLabel.isHidden = true

        // Calculate frame for video player to fill available space
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        
        // Create frame that uses available space between navigation and tab bar
        let videoFrame = CGRect(
            x: 0,
            y: view.safeAreaInsets.top,
            width: view.bounds.width,
            height: view.bounds.height - view.safeAreaInsets.top - tabBarHeight
        )
        
        // Store initial frame for maximization
        initialWebViewFrame = videoFrame
        webView.frame = initialWebViewFrame

        let embedHTML = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { 
                    margin: 0; 
                    padding: 0;
                    background-color: black;
                    overflow: hidden;
                }
                #player {
                    width: 100%;
                    height: 100%;
                    aspect-ratio: 16/9;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                var player;
                var startTime;

                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        height: '100%',
                        width: '100%',
                        videoId: '\(videoID)',
                        playerVars: { 
                            'autoplay': 1, 
                            'playsinline': 1,
                            'controls': 1,
                            'rel': 0,
                            'modestbranding': 1
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange
                        }
                    });
                }

                function onPlayerReady(event) {
                    startTime = new Date().getTime(); // Record start time
                    event.target.playVideo();
                    // Notify iOS that player is ready
                    window.webkit.messageHandlers.videoPlayer.postMessage({'event': 'playerReady'});
                }

                function onPlayerStateChange(event) {
                    if (event.data == YT.PlayerState.ENDED) {
                        var endTime = new Date().getTime();
                        var duration = (endTime - startTime) / 1000; // in seconds
                        window.webkit.messageHandlers.videoPlayer.postMessage({'event': 'ended', 'duration': duration});
                    } else if (event.data == YT.PlayerState.PLAYING) {
                        // Check if played for at least 5 minutes (300 seconds)
                        setTimeout(function() {
                            if (player.getPlayerState() == YT.PlayerState.PLAYING) {
                                var currentTime = player.getCurrentTime();
                                if (currentTime >= 300) { // 5 minutes
                                    window.webkit.messageHandlers.videoPlayer.postMessage({'event': 'playedFor5Minutes'});
                                }
                            }
                        }, 300000); // Check after 5 minutes
                    }
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(embedHTML, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Loading overlay will be hidden when YouTube player is ready
        // via the 'playerReady' message handler
    }

    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "videoPlayer" {
            if let body = message.body as? [String: Any], let event = body["event"] as? String {
                if event == "playerReady" {
                    // Video player is ready, hide loading overlay
                    overlayView.isHidden = true
                    spinner.stopAnimating()
                    webView.isHidden = false
                } else if event == "ended" {
                    // Video ended, record watched and close webView
                    ChallengeManager.shared.recordVideoWatched()
                    webView.isHidden = true
                    
                    let alert = UIAlertController(title: LanguageManager.shared.localizedString(for: "goal_achieved"), message: LanguageManager.shared.localizedString(for: "continue_habit_tomorrow"), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default, handler: { [weak self] _ in
                        // アラートが閉じられた後にUIを更新
                        self?.updateChallengeUIState()
                    }))
                    self.present(alert, animated: true, completion: nil)
                } else if event == "playedFor5Minutes" {
                    // Played for 5 minutes, record watched
                    ChallengeManager.shared.recordVideoWatched()
                    // No need to close webView here, user might continue watching
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func startChallengeFlow() {
        let costs = [1000, 5000, 10000]
        let costTitles = [
            LanguageManager.shared.localizedString(for: "resolve_credit_1000"),
            LanguageManager.shared.localizedString(for: "resolve_credit_5000"),
            LanguageManager.shared.localizedString(for: "resolve_credit_10000")
        ]
        
        let costSelectionAlert = UIAlertController(
            title: LanguageManager.shared.localizedString(for: "challenge_select_credits"),
            message: LanguageManager.shared.localizedString(for: "challenge_select_credits_message"),
            preferredStyle: .actionSheet
        )
        
        for (index, cost) in costs.enumerated() {
            costSelectionAlert.addAction(UIAlertAction(title: costTitles[index], style: .default, handler: { [weak self] _ in
                self?.promptForTargetMoney(selectedCost: cost)
            }))
        }
        costSelectionAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "cancel"), style: .cancel))
        present(costSelectionAlert, animated: true)
    }

    private func promptForTargetMoney(selectedCost: Int) {
        let targetAmountAlert = UIAlertController(
            title: LanguageManager.shared.localizedString(for: "challenge_target_amount_title"),
            message: LanguageManager.shared.localizedString(for: "challenge_target_amount_message"),
            preferredStyle: .alert
        )
        targetAmountAlert.addTextField { textField in
            textField.placeholder = LanguageManager.shared.localizedString(for: "challenge_target_placeholder")
            textField.keyboardType = .numberPad
        }
        targetAmountAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "cancel"), style: .cancel))
        targetAmountAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "challenge_set"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            if let text = targetAmountAlert.textFields?.first?.text, let targetMoney = Int(text), targetMoney > 0 {
                self.confirmAndStartChallenge(selectedCost: selectedCost, targetMoney: targetMoney)
            } else {
                let errorAlert = UIAlertController(
                    title: LanguageManager.shared.localizedString(for: "error_title"),
                    message: LanguageManager.shared.localizedString(for: "error_invalid_amount"),
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default))
                self.present(errorAlert, animated: true)
            }
        }))
        present(targetAmountAlert, animated: true)
    }

    private func confirmAndStartChallenge(selectedCost: Int, targetMoney: Int) {
        let message = String(format: LanguageManager.shared.localizedString(for: "challenge_start_message"), selectedCost, targetMoney)
        let confirmAlert = UIAlertController(
            title: LanguageManager.shared.localizedString(for: "challenge_start_title"),
            message: message,
            preferredStyle: .alert
        )
        confirmAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "cancel"), style: .cancel))
        confirmAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "challenge_start_button"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            if ChallengeManager.shared.startChallenge(cost: selectedCost, targetMoney: targetMoney) {
                // 成功時の処理
                let successAlert = UIAlertController(
                    title: LanguageManager.shared.localizedString(for: "challenge_success_title"),
                    message: LanguageManager.shared.localizedString(for: "challenge_start_success_message"),
                    preferredStyle: .alert
                )
                successAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default, handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.tabBarController?.selectedIndex = 2 // 覚悟チャレンジ画面へ (index 2)
                }))
                self.present(successAlert, animated: true)
            } else {
                // 失敗時の処理
                let errorAlert = UIAlertController(
                    title: LanguageManager.shared.localizedString(for: "challenge_failed_title"),
                    message: LanguageManager.shared.localizedString(for: "challenge_start_failed_message"),
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default, handler: { [weak self] _ in
                    // エラーアラートが閉じられた後、UIを更新してチャレンジ前の状態に戻す
                    self?.updateChallengeUIState() // チャレンジ関連UIを更新
                    self?.checkAndSchedulePlay() // 動画再生関連UIを更新
                }))
                self.present(errorAlert, animated: true)
            }
        }))
        self.present(confirmAlert, animated: true)
    }

    // MARK: - Video Minimization Logic
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // Only allow pan if webView is visible and not already minimized
        guard !webView.isHidden && !isMinimized else {
            return
        }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        if gesture.state == .changed {
            // Only react to downward swipe
            if translation.y > 0 {
                // Calculate new frame based on translation
                let newY = max(0, initialWebViewFrame.origin.y + translation.y)
                let newHeight = max(initialWebViewFrame.height - translation.y, 0)
                let newWidth = newHeight * (initialWebViewFrame.width / initialWebViewFrame.height) // Maintain aspect ratio

                // Calculate new X to keep it centered horizontally during vertical drag, then move to right
                let currentCenterX = initialWebViewFrame.midX + translation.x
                let targetX = view.bounds.width - newWidth - 10 // Target for minimized state

                // Interpolate X position from center to targetX
                let progress = min(1, translation.y / (view.bounds.height * 0.5)) // Progress based on vertical drag
                let interpolatedX = initialWebViewFrame.midX - (initialWebViewFrame.width / 2) + (targetX - (initialWebViewFrame.midX - (initialWebViewFrame.width / 2))) * progress

                self.webView.frame = CGRect(x: interpolatedX, y: newY, width: newWidth, height: newHeight)
            }
        } else if gesture.state == .ended {
            // If swiped down significantly or with high velocity, minimize
            if translation.y > view.bounds.height * 0.2 || velocity.y > 500 {
                minimizePlayer()
            } else { // Otherwise, return to full screen
                maximizePlayer()
            }
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isMinimized else { return }
        maximizePlayer()
    }

    private func minimizePlayer() {
        isMinimized = true
        tapGesture.isEnabled = true
        panGesture.isEnabled = false // Disable pan when minimized

        let smallWidth = view.bounds.width * 0.4
        let smallHeight = smallWidth * (9.0 / 16.0) // 16:9 aspect ratio
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        
        let newFrame = CGRect(
            x: view.bounds.width - smallWidth - 10,
            y: view.bounds.height - smallHeight - tabBarHeight - 10,
            width: smallWidth,
            height: smallHeight
        )

        UIView.animate(withDuration: 0.3) {
            self.webView.frame = newFrame
        }
    }

    private func maximizePlayer(animated: Bool = true) {
        isMinimized = false
        tapGesture.isEnabled = false
        panGesture.isEnabled = true // Enable pan when maximized

        let animations = {
            self.webView.frame = self.initialWebViewFrame // Restore to initial full screen frame
        }

        if animated {
            UIView.animate(withDuration: 0.3, animations: animations)
        } else {
            animations()
        }
    }

    // MARK: - VideoManagerDelegate
    func videoManager(_ manager: VideoManager, didUpdateMinimizedState isMinimized: Bool) {
        // Handle UI updates when video is minimized/maximized
        if !isMinimized {
            // Video is maximized, hide challenge UI
            newChallengeEntryButton.isHidden = true
            challengeIntroLabel.isHidden = true
            waitingLabel.isHidden = true
            playNowButton.isHidden = true
        }
        overlayView.isHidden = true
        spinner.stopAnimating()
    }
    
    func videoManager(_ manager: VideoManager, shouldSwitchToHomeTab: Void) {
        // Switch to Home tab when video is maximized
        DispatchQueue.main.async {
            self.tabBarController?.selectedIndex = 0
        }
    }
    
    func videoManager(_ manager: VideoManager, didStopVideo: Void) {
        // Restore replay button when video is manually stopped
        restoreReplayButton()
    }
    
    func videoManager(_ manager: VideoManager, didCompleteVideo duration: TimeInterval) {
        // Video ended, record watched
        ChallengeManager.shared.recordVideoWatched()
        
        let alert = UIAlertController(title: LanguageManager.shared.localizedString(for: "goal_achieved"), message: LanguageManager.shared.localizedString(for: "continue_habit_tomorrow"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LanguageManager.shared.localizedString(for: "ok"), style: .default, handler: { [weak self] _ in
            VideoManager.shared.stopVideo()
            self?.restoreReplayButton()
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    // Restore "もう一度見る" button when video is stopped
    private func restoreReplayButton() {
        DispatchQueue.main.async {
            let hasWatchedToday = ChallengeManager.shared.hasWatchedToday()
            if hasWatchedToday {
                self.playNowButton.setTitle(LanguageManager.shared.localizedString(for: "watch_again"), for: .normal)
                self.playNowButton.isHidden = false
                self.waitingLabel.isHidden = true
                self.newChallengeEntryButton.isHidden = true
                self.challengeIntroLabel.isHidden = true
                
                // Force UI update
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            } else {
                self.updateChallengeUIState()
            }
        }
    }
    
    func videoManager(_ manager: VideoManager, didPlayFor5Minutes: Void) {
        // Played for 5 minutes, record watched
        ChallengeManager.shared.recordVideoWatched()
        
        // Check if day changed during video watching (failure condition)
        checkMidnightFailure()
    }
    
    /// 動画視聴中に日付が変わった場合の失敗チェック
    private func checkMidnightFailure() {
        guard let challenge = ChallengeManager.shared.currentChallenge, 
              challenge.isActive && !challenge.isFailed && !challenge.isCompleted else {
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // 5分以上視聴が完了しないまま日付が変わった場合の処理は
        // ChallengeManager.checkChallengeStatus() で自動的に処理される
        // ここでは単純にステータスチェックを実行
        ChallengeManager.shared.checkChallengeStatus()
    }

    // MARK: - Challenge UI State Update
    private func updateChallengeUIState() {
        print("ViewController: updateChallengeUIState called.")
        
        // Don't update UI if video is currently playing - let video control the UI
        if VideoManager.shared.hasActiveVideo {
            print("  Video is active, skipping UI update")
            return
        }
        
        // Always reset webView to hidden state when updating challenge UI
        webView.isHidden = true
        
        let currentChallenge = ChallengeManager.shared.currentChallenge
        let challengeActive = currentChallenge?.isActive ?? false
        let challengeCompleted = currentChallenge?.isCompleted ?? false
        let challengeFailed = currentChallenge?.isFailed ?? false

        print("  currentChallenge state: isActive=\(challengeActive), isFailed=\(challengeFailed), isCompleted=\(challengeCompleted)")

        // Clear any existing state first
        waitingLabel.isHidden = true
        playNowButton.isHidden = true
        
        if challengeActive {
            // Active challenge: hide challenge UI, let checkAndSchedulePlay handle video UI
            newChallengeEntryButton.isHidden = true
            challengeIntroLabel.isHidden = true
            print("  UI State: Challenge Active. newChallengeEntryButton.isHidden=\(newChallengeEntryButton.isHidden), challengeIntroLabel.isHidden=\(challengeIntroLabel.isHidden)")
            
            // For active challenges, call checkAndSchedulePlay to handle video timing
            checkAndSchedulePlay()
        } else {
            // No active challenge: show appropriate challenge entry state
            newChallengeEntryButton.isHidden = false
            challengeIntroLabel.isHidden = false
            
            if challengeCompleted {
                challengeIntroLabel.text = LanguageManager.shared.localizedString(for: "challenge_completed_message")
                print("  UI State: Challenge Completed. Showing new challenge entry.")
            } else if challengeFailed {
                challengeIntroLabel.text = LanguageManager.shared.localizedString(for: "challenge_failed_message")
                print("  UI State: Challenge Failed. Showing new challenge entry.")
            } else {
                // No challenge exists
                challengeIntroLabel.text = LanguageManager.shared.localizedString(for: "home_intro_text")
                print("  UI State: No Challenge. Showing new challenge entry.")
            }
        }
    }
}
