//
//  VideoManager.swift
//  YouStarterMVP
//
//  Video playback manager for cross-tab persistence
//

import UIKit
import WebKit

// Helper extension for finding top view controller
extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigation = self as? UINavigationController,
           let visible = navigation.visibleViewController {
            return visible.topMostViewController()
        }
        
        if let tab = self as? UITabBarController,
           let selected = tab.selectedViewController {
            return selected.topMostViewController()
        }
        
        return self
    }
}

protocol VideoManagerDelegate: AnyObject {
    func videoManager(_ manager: VideoManager, didUpdateMinimizedState isMinimized: Bool)
    func videoManager(_ manager: VideoManager, didCompleteVideo duration: TimeInterval)
    func videoManager(_ manager: VideoManager, didPlayFor5Minutes: Void)
    func videoManager(_ manager: VideoManager, shouldSwitchToHomeTab: Void)
    func videoManager(_ manager: VideoManager, didStopVideo: Void)
}

class VideoManager: NSObject {
    static let shared = VideoManager()
    
    weak var delegate: VideoManagerDelegate?
    private var webView: WKWebView?
    private var containerWindow: UIWindow?
    private var tapOverlay: UIView? // Transparent overlay for tap detection
    private var stopButton: UIButton? // Stop button for replay videos
    private var replayOverlay: UIView? // Overlay for maximized replay videos
    private var replayLabel: UILabel? // "もう一度見る" label
    private var isMinimized = false
    private var isVideoActive = false
    private var isReplayVideo = false // Track if this is a replay
    private var initialFrame: CGRect = .zero
    
    private override init() {
        super.init()
    }
    
    // MARK: - Video Playback
    func startVideo(videoID: String, in window: UIWindow, isReplay: Bool = false) {
        guard !isVideoActive else { return }
        
        self.containerWindow = window
        self.isReplayVideo = isReplay
        setupWebView()
        loadYouTubeVideo(videoID: videoID)
        isVideoActive = true
    }
    
    func stopVideo() {
        // Re-enable tab bar interaction when video stops
        if let window = containerWindow,
           let tabBarController = window.rootViewController as? UITabBarController {
            tabBarController.tabBar.isUserInteractionEnabled = true
        }
        
        removeTapOverlay()
        removeStopButton()
        removeReplayOverlay()
        webView?.removeFromSuperview()
        webView = nil
        isVideoActive = false
        isMinimized = false
        isReplayVideo = false
        delegate?.videoManager(self, didUpdateMinimizedState: false)
    }
    
    // MARK: - Minimize/Maximize
    func minimizeVideo() {
        guard let webView = webView, let window = containerWindow, !isMinimized else { return }
        
        isMinimized = true
        
        // Re-enable tab bar interaction when minimized
        if let tabBarController = window.rootViewController as? UITabBarController {
            tabBarController.tabBar.isUserInteractionEnabled = true
        }
        
        let smallWidth = window.bounds.width * 0.4
        let smallHeight = smallWidth * (9.0 / 16.0)
        
        // Get tab bar height from the window's root view controller
        var tabBarHeight: CGFloat = 0
        if let tabBarController = window.rootViewController as? UITabBarController {
            tabBarHeight = tabBarController.tabBar.frame.height
        }
        
        let newFrame = CGRect(
            x: window.bounds.width - smallWidth - 10,
            y: window.bounds.height - smallHeight - tabBarHeight - 10,
            width: smallWidth,
            height: smallHeight
        )
        
        // Disable YouTube controls when minimized
        disableYouTubeControls()
        
        // Create tap overlay for minimized video
        setupTapOverlay(frame: newFrame)
        
        // Remove replay overlay when minimized
        removeReplayOverlay()
        
        UIView.animate(withDuration: 0.3) {
            webView.frame = newFrame
        }
        
        delegate?.videoManager(self, didUpdateMinimizedState: true)
    }
    
    func maximizeVideo() {
        guard let webView = webView, let window = containerWindow, isMinimized else { return }
        
        isMinimized = false
        
        // Switch to Home tab before maximizing
        delegate?.videoManager(self, shouldSwitchToHomeTab: ())
        
        // Disable tab bar interaction when maximized
        if let tabBarController = window.rootViewController as? UITabBarController {
            tabBarController.tabBar.isUserInteractionEnabled = false
        }
        
        // Calculate full frame
        let tabBarHeight: CGFloat
        if let tabBarController = window.rootViewController as? UITabBarController {
            tabBarHeight = tabBarController.tabBar.frame.height
        } else {
            tabBarHeight = 0
        }
        
        let fullFrame = CGRect(
            x: 0,
            y: window.safeAreaInsets.top,
            width: window.bounds.width,
            height: window.bounds.height - window.safeAreaInsets.top - tabBarHeight
        )
        
        // Re-enable YouTube controls when maximized
        enableYouTubeControls()
        
        // Remove tap overlay, stop button, and replay overlay
        removeTapOverlay()
        removeStopButton()
        removeReplayOverlay()
        
        UIView.animate(withDuration: 0.3) {
            webView.frame = fullFrame
        } completion: { _ in
            // Show replay overlay again when maximized (if replay video)
            if self.isReplayVideo {
                self.setupReplayOverlay()
            }
        }
        
        delegate?.videoManager(self, didUpdateMinimizedState: false)
    }
    
    // MARK: - Private Methods
    private func setupWebView() {
        guard let window = containerWindow else { return }
        
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "videoPlayer")
        
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView?.navigationDelegate = self
        webView?.backgroundColor = .black
        webView?.isOpaque = false
        
        // Disable zoom gestures
        webView?.scrollView.isScrollEnabled = false
        webView?.scrollView.bounces = false
        webView?.scrollView.bouncesZoom = false
        webView?.scrollView.minimumZoomScale = 1.0
        webView?.scrollView.maximumZoomScale = 1.0
        
        // Add tap gesture for maximizing when minimized
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        webView?.addGestureRecognizer(tapGesture)
        
        // Add pan gesture for minimizing
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        webView?.addGestureRecognizer(panGesture)
        
        window.addSubview(webView!)
    }
    
    private func loadYouTubeVideo(videoID: String) {
        guard let webView = webView, let window = containerWindow else { return }
        
        // Calculate initial full frame
        let tabBarHeight: CGFloat
        if let tabBarController = window.rootViewController as? UITabBarController {
            tabBarHeight = tabBarController.tabBar.frame.height
        } else {
            tabBarHeight = 0
        }
        
        initialFrame = CGRect(
            x: 0,
            y: window.safeAreaInsets.top,
            width: window.bounds.width,
            height: window.bounds.height - window.safeAreaInsets.top - tabBarHeight
        )
        
        webView.frame = initialFrame
        
        // Add replay overlay if this is a replay video
        if isReplayVideo {
            setupReplayOverlay()
        }
        
        let embedHTML = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                body { 
                    margin: 0; 
                    padding: 0;
                    background-color: black;
                    overflow: hidden;
                    touch-action: none;
                    position: relative;
                }
                #player {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                }
                iframe {
                    width: 100% !important;
                    height: 100% !important;
                    border: none;
                    pointer-events: auto;
                }
                #custom-controls {
                    position: absolute;
                    top: 10px;
                    right: 10px;
                    z-index: 1000;
                    display: flex;
                    gap: 8px;
                    align-items: center;
                }
                .control-button {
                    width: 40px;
                    height: 40px;
                    background: rgba(0, 0, 0, 0.7);
                    border: none;
                    border-radius: 20px;
                    color: white;
                    font-size: 18px;
                    font-weight: bold;
                    cursor: pointer;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    transition: background 0.2s;
                }
                .control-button:hover {
                    background: rgba(0, 0, 0, 0.9);
                }
                #close-button {
                    font-size: 24px;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <div id="custom-controls">
                <button class="control-button" id="close-button" onclick="closeVideo()">×</button>
            </div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                var player;
                var startTime;
                var isMuted = false;

                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        height: '100%',
                        width: '100%',
                        videoId: '\(videoID)',
                        playerVars: { 
                            'autoplay': 1, 
                            'playsinline': 1,
                            'controls': 0,
                            'rel': 0,
                            'modestbranding': 1,
                            'showinfo': 0,
                            'fs': 0,
                            'cc_load_policy': 0,
                            'iv_load_policy': 3,
                            'disablekb': 1
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange
                        }
                    });
                }

                function onPlayerReady(event) {
                    startTime = new Date().getTime();
                    event.target.playVideo();
                    window.webkit.messageHandlers.videoPlayer.postMessage({'event': 'playerReady'});
                }

                function onPlayerStateChange(event) {
                    if (event.data == YT.PlayerState.ENDED) {
                        var endTime = new Date().getTime();
                        var duration = (endTime - startTime) / 1000;
                        window.webkit.messageHandlers.videoPlayer.postMessage({'event': 'ended', 'duration': duration});
                    } else if (event.data == YT.PlayerState.PLAYING) {
                        setTimeout(function() {
                            if (player.getPlayerState() == YT.PlayerState.PLAYING) {
                                var currentTime = player.getCurrentTime();
                                if (currentTime >= 300) {
                                    window.webkit.messageHandlers.videoPlayer.postMessage({'event': 'playedFor5Minutes'});
                                }
                            }
                        }, 300000);
                    }
                }

                function closeVideo() {
                    window.webkit.messageHandlers.videoPlayer.postMessage({'event': 'closeRequested'});
                }

                // Hide custom controls when minimized, show when maximized
                function toggleCustomControls(show) {
                    document.getElementById('custom-controls').style.display = show ? 'flex' : 'none';
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(embedHTML, baseURL: nil)
    }
    
    // MARK: - YouTube Controls Management
    private func disableYouTubeControls() {
        let disableControlsJS = """
            if (player) {
                // Hide YouTube controls overlay
                var iframe = document.querySelector('iframe');
                if (iframe) {
                    iframe.style.pointerEvents = 'none';
                }
                // Also disable player interactions
                var playerElement = document.getElementById('player');
                if (playerElement) {
                    playerElement.style.pointerEvents = 'none';
                }
                // Hide custom controls when minimized
                toggleCustomControls(false);
            }
        """
        webView?.evaluateJavaScript(disableControlsJS, completionHandler: nil)
    }
    
    private func enableYouTubeControls() {
        let enableControlsJS = """
            if (player) {
                // Re-enable YouTube controls
                var iframe = document.querySelector('iframe');
                if (iframe) {
                    iframe.style.pointerEvents = 'auto';
                }
                var playerElement = document.getElementById('player');
                if (playerElement) {
                    playerElement.style.pointerEvents = 'auto';
                }
                // Show custom controls when maximized
                toggleCustomControls(true);
            }
        """
        webView?.evaluateJavaScript(enableControlsJS, completionHandler: nil)
    }
    
    // MARK: - Tap Overlay Management
    private func setupTapOverlay(frame: CGRect) {
        guard let window = containerWindow else { return }
        
        removeTapOverlay() // Remove existing overlay if any
        
        tapOverlay = UIView(frame: frame)
        tapOverlay?.backgroundColor = UIColor.clear
        tapOverlay?.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        tapOverlay?.addGestureRecognizer(tapGesture)
        
        window.addSubview(tapOverlay!)
        
        // Add stop button if this is a replay video
        if isReplayVideo {
            setupStopButton(overlayFrame: frame)
        }
    }
    
    private func removeTapOverlay() {
        tapOverlay?.removeFromSuperview()
        tapOverlay = nil
    }
    
    // MARK: - Stop Button Management
    private func setupStopButton(overlayFrame: CGRect) {
        guard let window = containerWindow else { return }
        
        removeStopButton() // Remove existing button if any
        
        stopButton = UIButton(type: .system)
        stopButton?.setTitle("×", for: .normal)
        stopButton?.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        stopButton?.setTitleColor(.white, for: .normal)
        stopButton?.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        stopButton?.layer.cornerRadius = 15
        stopButton?.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        
        // Position stop button at top-right of minimized video
        let buttonSize: CGFloat = 30
        let buttonFrame = CGRect(
            x: overlayFrame.maxX - buttonSize - 5,
            y: overlayFrame.minY + 5,
            width: buttonSize,
            height: buttonSize
        )
        
        stopButton?.frame = buttonFrame
        window.addSubview(stopButton!)
    }
    
    private func removeStopButton() {
        stopButton?.removeFromSuperview()
        stopButton = nil
    }
    
    @objc private func stopButtonTapped() {
        // チャレンジ中かどうかを確認
        let isActiveChallenge = ChallengeManager.shared.currentChallenge?.isActive == true
        
        if isActiveChallenge {
            // アクティブなチャレンジ中の場合、アラートなしで直接停止
            print("VideoManager: チャレンジ中のため、アラートなしで動画を停止します")
            
            // Switch back to home first
            delegate?.videoManager(self, shouldSwitchToHomeTab: ())
            
            // Small delay to ensure tab switch completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.delegate?.videoManager(self, didStopVideo: ())
                self.stopVideo()
            }
            return
        }
        
        // チャレンジ中でない場合、確認アラートを表示
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let topViewController = window.rootViewController?.topMostViewController() else {
            return
        }
        
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
                // Switch back to home first
                self.delegate?.videoManager(self, shouldSwitchToHomeTab: ())
                
                // Small delay to ensure tab switch completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.delegate?.videoManager(self, didStopVideo: ())
                    self.stopVideo()
                }
            }
        ))
        
        topViewController.present(alert, animated: true)
    }
    
    // MARK: - Video Control Overlay Management (for all maximized videos)
    private func setupReplayOverlay() {
        guard let window = containerWindow else { return }
        
        removeReplayOverlay() // Remove existing overlay if any
        
        // Create overlay that doesn't interfere with video gestures
        replayOverlay = UIView(frame: initialFrame)
        replayOverlay?.backgroundColor = UIColor.clear
        replayOverlay?.isUserInteractionEnabled = false // Don't block video gestures
        
        // Add overlay to window (no native stop button since we use HTML controls)
        window.addSubview(replayOverlay!)
    }
    
    private func hideReplayOverlay() {
        UIView.animate(withDuration: 0.3) {
            self.replayOverlay?.alpha = 0
        } completion: { _ in
            self.replayOverlay?.isHidden = true
        }
    }
    
    private func removeReplayOverlay() {
        replayOverlay?.removeFromSuperview()
        replayOverlay = nil
        replayLabel = nil
    }
    
    @objc private func overlayTapped() {
        maximizeVideo()
    }

    // MARK: - Gesture Handlers
    @objc private func handleTap() {
        // This is now handled by the overlay tap
        // Keep for compatibility but overlay takes priority
        if isMinimized {
            maximizeVideo()
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let webView = webView, !isMinimized else { return }
        
        let translation = gesture.translation(in: webView.superview)
        let velocity = gesture.velocity(in: webView.superview)
        
        if gesture.state == .changed {
            if translation.y > 0 {
                let newY = max(initialFrame.origin.y, initialFrame.origin.y + translation.y)
                let newHeight = max(initialFrame.height - translation.y, 0)
                let newWidth = newHeight * (initialFrame.width / initialFrame.height)
                
                let progress = min(1, translation.y / (initialFrame.height * 0.5))
                let targetX = (webView.superview?.bounds.width ?? 0) - newWidth - 10
                let interpolatedX = initialFrame.origin.x + (targetX - initialFrame.origin.x) * progress
                
                webView.frame = CGRect(x: interpolatedX, y: newY, width: newWidth, height: newHeight)
            }
        } else if gesture.state == .ended {
            // More sensitive thresholds to prevent getting stuck in middle state
            let minimizeThreshold = initialFrame.height * 0.15 // Reduced from 0.2 to 0.15
            let velocityThreshold: CGFloat = 300 // Reduced from 500 to 300
            
            if translation.y > minimizeThreshold || velocity.y > velocityThreshold {
                minimizeVideo()
            } else {
                // Always return to maximized if below threshold
                maximizeVideo()
            }
        } else if gesture.state == .cancelled || gesture.state == .failed {
            // Ensure we return to maximized state if gesture is cancelled
            maximizeVideo()
        }
    }
    
    // MARK: - Public Properties
    var isVideoMinimized: Bool {
        return isMinimized
    }
    
    var hasActiveVideo: Bool {
        return isVideoActive
    }
}

// MARK: - WKNavigationDelegate
extension VideoManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Loading handled by playerReady message
    }
}

// MARK: - WKScriptMessageHandler
extension VideoManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "videoPlayer" {
            if let body = message.body as? [String: Any], let event = body["event"] as? String {
                switch event {
                case "playerReady":
                    // Record video start time for challenge tracking
                    ChallengeManager.shared.recordVideoStartTime()
                    // Setup overlay when video is ready
                    setupReplayOverlay()
                    // Show custom controls if maximized
                    if !isMinimized {
                        enableYouTubeControls()
                    }
                case "ended":
                    if let duration = body["duration"] as? TimeInterval {
                        delegate?.videoManager(self, didCompleteVideo: duration)
                    }
                case "playedFor5Minutes":
                    delegate?.videoManager(self, didPlayFor5Minutes: ())
                case "closeRequested":
                    // Handle close button tap from JavaScript
                    stopButtonTapped()
                default:
                    break
                }
            }
        }
    }
}