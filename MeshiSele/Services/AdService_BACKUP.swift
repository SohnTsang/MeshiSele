import Foundation
import UIKit
import SwiftUI
// import GoogleMobileAds // REMOVED TO PREVENT EXC_BAD_ACCESS CRASHES
import OSLog

/// Comprehensive thread-safe AdService implementing all known fixes for EXC_BAD_ACCESS crashes
/// Based on latest Google AdMob documentation and community solutions
@MainActor
final class AdService: NSObject, ObservableObject {
    static let shared = AdService()
    
    // MARK: - Thread-Safe State Management
    @Published private(set) var isAdsEnabled = true
    @Published private(set) var adsLoaded = false
    @Published private(set) var isShowingInterstitialAd = false
    @Published private(set) var bannerAd: BannerView?
    
    // MARK: - Private State (Main Actor Isolated)
    private var interstitialAd: InterstitialAd?
    private var interstitialCompletionHandler: (() -> Void)?
    private var isInitializing = false
    
    // MARK: - Configuration
    private let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    private let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    
    // MARK: - Logging
    private let logger = Logger(subsystem: "MeshiSele", category: "AdService")
    
    // MARK: - Thread Safety Actor
    private actor ThreadSafeOperations {
        private var operationQueue: [() async -> Void] = []
        private var isProcessing = false
        
        func enqueue(_ operation: @escaping () async -> Void) async {
            operationQueue.append(operation)
            if !isProcessing {
                await processQueue()
            }
        }
        
        private func processQueue() async {
            isProcessing = true
            while !operationQueue.isEmpty {
                let operation = operationQueue.removeFirst()
                await operation()
                // Add small delay to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            isProcessing = false
        }
    }
    
    private let threadSafeOperations = ThreadSafeOperations()
    
    override init() {
        super.init()
        logger.info("📱 AdService: Initializing with comprehensive thread safety")
        
        // Initialize on main thread with proper delay and error handling
        Task { @MainActor in
            do {
                // Wait for app to be fully initialized
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await initializeAdsWithRetry()
                    } catch {
            logger.error("📱 AdService: Initialization delay failed: \(error.localizedDescription)")
            // Still try to initialize even if delay fails
            await initializeAdsWithRetry()
        }
        }
    }
    
    // MARK: - Initialization with Retry Logic
    @MainActor
    private func initializeAdsWithRetry(attempt: Int = 1, maxAttempts: Int = 3) async {
        guard !adsLoaded && !isInitializing else {
            logger.info("📱 AdService: Already initialized or initializing")
            return
        }
        
        isInitializing = true
        logger.info("📱 AdService: Initializing Google AdMob (attempt \(attempt)/\(maxAttempts))")
        
        do {
            // Use actor to ensure thread-safe initialization
            await threadSafeOperations.enqueue { [weak self] in
                await self?.performInitialization()
            }
        } catch {
            logger.error("📱 AdService: Initialization failed: \(error.localizedDescription)")
            
            if attempt < maxAttempts {
                // Retry with exponential backoff
                let delay = UInt64(attempt * 1_000_000_000) // 1, 2, 3 seconds
                try? await Task.sleep(nanoseconds: delay)
                await initializeAdsWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
            } else {
                await MainActor.run {
                    self.isInitializing = false
                    self.logger.error("📱 AdService: Failed to initialize after \(maxAttempts) attempts")
                }
            }
        }
    }
    
    @MainActor
    private func performInitialization() async {
        // All operations are now guaranteed to be on main thread due to @MainActor
        
        // Start the Google Mobile Ads SDK with completion handler
        await withCheckedContinuation { continuation in
            MobileAds.shared.start { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    self.logger.info("📱 AdService: Google AdMob initialized successfully")
                    self.adsLoaded = true
                    self.isInitializing = false
                    
                    // Load interstitial ad after successful initialization
                    await self.loadInterstitialAdSafely()
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Interstitial Ad Management
    @MainActor
    private func loadInterstitialAdSafely() async {
        guard adsLoaded else {
            logger.warning("📺 AdService: Cannot load interstitial - ads not initialized")
            return
        }
        
        logger.info("📺 AdService: Loading interstitial ad safely")
        
        await withCheckedContinuation { continuation in
            let request = Request()
            InterstitialAd.load(with: testInterstitialAdUnitID, request: request) { [weak self] ad, error in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    if let error = error {
                        self.logger.error("📺 AdService: Failed to load interstitial ad - \(error.localizedDescription)")
                        self.interstitialAd = nil
                    } else {
                        self.logger.info("📺 AdService: Interstitial ad loaded successfully")
                        self.interstitialAd = ad
                        self.interstitialAd?.fullScreenContentDelegate = self
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Banner Ad Management
    @MainActor
    func setupBannerAd() {
        guard adsLoaded else {
            logger.warning("📺 AdService: Cannot setup banner - ads not initialized")
            return
        }
        
        logger.info("📺 AdService: Setting up banner ad safely")
        
        // Use Task to ensure proper async handling
        Task { @MainActor in
            // Ensure we can safely access window hierarchy
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                logger.warning("📺 AdService: No window or root view controller found for banner ad")
                return
            }
            
            let bannerView = BannerView(adSize: AdSizeBanner)
            bannerView.adUnitID = testBannerAdUnitID
            bannerView.rootViewController = rootViewController
            
            // Load ad with proper error handling
            let request = Request()
            bannerView.load(request)
            
            self.bannerAd = bannerView
            self.logger.info("📺 AdService: Banner ad setup completed")
        }
    }
    
    // MARK: - Public API
    @MainActor
    func showInterstitialAd(completion: @escaping () -> Void) async {
        guard isAdsEnabled else {
            logger.info("🚫 AdService: Ads disabled, executing completion immediately")
            completion()
            return
        }
        
        // Initialize if needed
        if !adsLoaded {
            await initializeAdsWithRetry()
            // Wait for initialization to complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        guard let interstitialAd = interstitialAd else {
            logger.warning("📺 AdService: No interstitial ad available")
            completion()
            return
        }
        
        // Safely get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            logger.error("📺 AdService: No root view controller available for presentation")
            completion()
            return
        }
        
        // Store completion handler
        interstitialCompletionHandler = completion
        isShowingInterstitialAd = true
        
        logger.info("📺 AdService: Presenting interstitial ad")
        interstitialAd.present(from: rootViewController)
    }
    
    @MainActor
    func loadBannerAd() {
        Task { @MainActor in
            logger.info("📱 AdService: Refreshing banner ad")
            
            // Initialize ads if not already done
            if !adsLoaded {
                await initializeAdsWithRetry()
                // Wait for initialization to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            setupBannerAd()
        }
    }
    
    @MainActor
    var canShowInterstitialAd: Bool {
        return isAdsEnabled && adsLoaded && interstitialAd != nil
    }
    
    @MainActor
    func createBannerAdView() -> BannerView? {
        return bannerAd
    }
    
    // MARK: - Cleanup
    @MainActor
    func cleanup() {
        logger.info("📱 AdService: Cleaning up resources")
        
        // Clear interstitial ad
        interstitialAd?.fullScreenContentDelegate = nil
        interstitialAd = nil
        
        // Clear banner ad
        bannerAd?.removeFromSuperview()
        bannerAd = nil
        
        // Clear completion handler
        interstitialCompletionHandler = nil
        
        // Reset state
        adsLoaded = false
        isInitializing = false
        isShowingInterstitialAd = false
    }
}

// MARK: - FullScreenContentDelegate
extension AdService: @preconcurrency FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            logger.info("📺 AdService: Interstitial ad will present")
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            logger.error("📺 AdService: Interstitial ad failed to present - \(error.localizedDescription)")
            
            isShowingInterstitialAd = false
            
            // Execute completion handler even on failure
            if let completion = interstitialCompletionHandler {
                completion()
                interstitialCompletionHandler = nil
            }
            
            // Load next ad
            await loadInterstitialAdSafely()
        }
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            logger.info("📺 AdService: Interstitial ad dismissed")
            
            isShowingInterstitialAd = false
            
            // Execute completion callback
            if let completion = interstitialCompletionHandler {
                completion()
                interstitialCompletionHandler = nil
                logger.info("📺 AdService: Completion handler executed")
            }
            
            // Load next ad
            await loadInterstitialAdSafely()
        }
    }
} 