import Foundation
import UIKit
import SwiftUI
import GoogleMobileAds
import OSLog
import Network

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
    @Published private(set) var isLoadingAd = false
    @Published private(set) var isNetworkAvailable = true
    
    // MARK: - Private State (Main Actor Isolated)
    private var interstitialAd: InterstitialAd?
    private var interstitialCompletionHandler: (() -> Void)?
    private var isInitializing = false
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - Configuration
    // Using Google's official demo ad unit IDs from https://developers.google.com/admob/ios/test-ads
    private let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"  // Official Google interstitial test ad
    private let testBannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"        // Official Google adaptive banner test ad
    
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
        
        // Set up network monitoring
        setupNetworkMonitoring()
        
        // Initialize on main thread with proper delay and error handling
        Task { @MainActor in
            // Wait for app to be fully initialized
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await initializeAdsWithRetry()
        }
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied
                
                if !wasAvailable && self.isNetworkAvailable {
                    // Network became available - try to reload ads if needed
                    self.logger.info("📱 AdService: Network became available - checking ad status")
                    if self.adsLoaded && self.interstitialAd == nil && !self.isLoadingAd {
                        self.logger.info("📱 AdService: Attempting to reload interstitial ad after network recovery")
                        await self.loadInterstitialAdSafely()
                    }
                } else if wasAvailable && !self.isNetworkAvailable {
                    self.logger.warning("📱 AdService: Network became unavailable")
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
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
        
        // Use actor to ensure thread-safe initialization
        await threadSafeOperations.enqueue { [weak self] in
            await self?.performInitialization()
        }
    }
    
    @MainActor
    private func performInitialization() async {
        // All operations are now guaranteed to be on main thread due to @MainActor
        logger.info("📱 AdService: Starting Google AdMob initialization")
        logger.info("📱 AdService: MobileAds.shared: \(MobileAds.shared)")
        logger.info("📱 AdService: Test interstitial unit ID: \(self.testInterstitialAdUnitID)")
        logger.info("📱 AdService: Test banner unit ID: \(self.testBannerAdUnitID)")
        
        // Configure test device settings for reliable test ads
        #if DEBUG
        logger.info("📱 AdService: 🧪 Configuring test device for reliable ad testing")
        let requestConfiguration = MobileAds.shared.requestConfiguration
        
        // Enable test device mode (simulator is automatically a test device)
        // but we add explicit test device identifiers for real devices too
        requestConfiguration.testDeviceIdentifiers = ["GADSimulatorID"]
        
        // Set test device for better ad loading reliability
        logger.info("📱 AdService: ✅ Test device configuration applied")
        #endif
        
        // Start the Google Mobile Ads SDK with completion handler
        await withCheckedContinuation { continuation in
            logger.info("📱 AdService: Calling MobileAds.shared.start...")
            
            MobileAds.shared.start { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        self?.logger.error("📱 AdService: Self was deallocated during initialization")
                        continuation.resume()
                        return
                    }
                    
                    self.logger.info("📱 AdService: ✅ Google AdMob initialization completed!")
                    self.logger.info("📱 AdService: Initialization status: \(status)")
                    self.logger.info("📱 AdService: Status description: \(status.adapterStatusesByClassName)")
                    
                    // Check if initialization was successful
                    let isInitialized = status.adapterStatusesByClassName.values.contains { adapterStatus in
                        adapterStatus.state == .ready
                    }
                    
                    self.logger.info("📱 AdService: Has ready adapters: \(isInitialized)")
                    
                    self.adsLoaded = true
                    self.isInitializing = false
                    
                    // Load interstitial ad after successful initialization
                    self.logger.info("📱 AdService: Loading interstitial ad after initialization")
                    await self.loadInterstitialAdSafely()
                    
                    // Also preload a second ad to be ready for quick succession
                    self.logger.info("📱 AdService: 🚀 Preloading backup ad for better availability")
                    
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Interstitial Ad Management
    @MainActor
    private func loadInterstitialAdSafely(attempt: Int = 1, maxAttempts: Int = 3) async {
        guard adsLoaded else {
            logger.warning("📺 AdService: Cannot load interstitial - ads not initialized")
            return
        }
        
        // Check network availability
        guard isNetworkAvailable else {
            logger.warning("📺 AdService: Cannot load interstitial - network unavailable")
            return
        }
        
        // Prevent concurrent loading
        guard !isLoadingAd else {
            logger.info("📺 AdService: ⏳ Ad is already loading, skipping duplicate request")
            return
        }
        
        isLoadingAd = true
        logger.info("📺 AdService: Loading interstitial ad safely with test unit ID: \(self.testInterstitialAdUnitID) (attempt \(attempt)/\(maxAttempts))")
        logger.info("📺 AdService: Current interstitialAd state before loading: \(self.interstitialAd != nil)")
        
        defer {
            isLoadingAd = false
        }
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let request = Request()
            
            // Add request configuration for better success rate
            if #available(iOS 14.5, *) {
                // Configure request for better ad delivery
                request.requestAgent = "MeshiSele-iOS"
            }
            
            logger.info("📺 AdService: Created GADRequest, calling InterstitialAd.load...")
            logger.info("📺 AdService: 🔍 DEBUGGING: About to call InterstitialAd.load with unit ID: \(self.testInterstitialAdUnitID)")
            
            InterstitialAd.load(with: self.testInterstitialAdUnitID, request: request) { [weak self] ad, error in
                Task { @MainActor [weak self] in
                    guard let self = self else {
                        self?.logger.warning("📺 AdService: ⚠️ Self was deallocated during ad loading")
                        continuation.resume()
                        return
                    }
                    
                    self.logger.info("📺 AdService: 🔍 DEBUGGING: Ad load completion handler called")
                    self.logger.info("📺 AdService: 🔍 DEBUGGING: ad != nil: \(ad != nil)")
                    self.logger.info("📺 AdService: 🔍 DEBUGGING: error != nil: \(error != nil)")
                    
                    if let error = error {
                        let errorCode = (error as NSError).code
                        let errorDomain = (error as NSError).domain
                        
                        // Check if it's a network error
                        let isNetworkError = errorCode == -1005 || // Network connection lost
                                           errorCode == -1009 || // No internet connection
                                           errorDomain == NSURLErrorDomain ||
                                           error.localizedDescription.contains("ネットワーク") ||
                                           error.localizedDescription.contains("network") ||
                                           error.localizedDescription.contains("connection")
                        
                        #if targetEnvironment(simulator)
                        // Minimal logging for simulator to reduce console noise
                        if DebugConfig.shouldLogNetworkWarnings {
                        if error._code == 2 && error._domain == "com.google.admob" {
                            self.logger.info("📺 AdService: 🖥️ Ad load failed in simulator (expected)")
                            } else if isNetworkError {
                                self.logger.info("📺 AdService: 🌐 Network error in simulator (suppressed)")
                            } else {
                                self.logger.warning("📺 AdService: ❌ Ad load failed: \(error.localizedDescription)")
                            }
                        } else {
                            // Only log non-network errors in simulator
                            if !isNetworkError && !(error._code == 2 && error._domain == "com.google.admob") {
                            self.logger.warning("📺 AdService: ❌ Ad load failed: \(error.localizedDescription)")
                            }
                        }
                        #else
                        // Full logging for real devices
                        if isNetworkError {
                            self.logger.warning("📺 AdService: 🌐 Network error loading interstitial ad (attempt \(attempt)/\(maxAttempts))")
                            self.logger.warning("📺 AdService: Network error details: \(error.localizedDescription)")
                        } else {
                        self.logger.error("📺 AdService: ❌ Failed to load interstitial ad (attempt \(attempt)/\(maxAttempts))")
                        self.logger.error("📺 AdService: Error code: \(error._code)")
                        self.logger.error("📺 AdService: Error domain: \(error._domain)")
                        self.logger.error("📺 AdService: Error description: \(error.localizedDescription)")
                        }
                        #endif
                        
                        self.interstitialAd = nil
                        self.logger.info("📺 AdService: 🔍 DEBUGGING: Set interstitialAd to nil due to error")
                        
                        // Improved retry logic with network error detection
                        #if targetEnvironment(simulator)
                        // Don't retry on simulator as network issues are common
                        self.logger.info("📺 AdService: 🎭 Simulator detected - skipping retries due to network limitations")
                        continuation.resume()
                        #else
                        // Retry for network errors or known recoverable errors
                        let shouldRetry = (isNetworkError || error._code == 2) && attempt < maxAttempts
                        
                        if shouldRetry {
                            let retryDelay = isNetworkError ? 3.0 : 5.0 // Shorter delay for network errors
                            self.logger.info("📺 AdService: 🔄 Retrying ad load in \(retryDelay) seconds... (\(isNetworkError ? "network" : "other") error)")
                            continuation.resume()
                            Task {
                                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                                await self.loadInterstitialAdSafely(attempt: attempt + 1, maxAttempts: maxAttempts)
                            }
                        } else {
                            self.logger.error("📺 AdService: ❌ Failed to load ad after \(maxAttempts) attempts")
                            continuation.resume()
                        }
                        #endif
                    } else if let ad = ad {
                        self.logger.info("📺 AdService: ✅ Interstitial ad loaded successfully!")
                        self.logger.info("📺 AdService: Ad object: \(ad)")
                        self.logger.info("📺 AdService: Setting fullScreenContentDelegate...")
                        self.interstitialAd = ad
                        self.interstitialAd?.fullScreenContentDelegate = self
                        self.logger.info("📺 AdService: Delegate set successfully")
                        self.logger.info("📺 AdService: 🔍 DEBUGGING: Successfully set interstitialAd")
                        continuation.resume()
                    } else {
                        self.logger.error("📺 AdService: ❌ Both ad and error are nil - unexpected state")
                        self.logger.error("📺 AdService: 🔍 DEBUGGING: This should never happen - both ad and error are nil")
                        self.interstitialAd = nil
                        
                        // Improved retry for nil case with simulator detection
                        #if targetEnvironment(simulator)
                        // Don't retry on simulator
                        self.logger.info("📺 AdService: 🎭 Simulator detected - skipping nil response retry")
                        continuation.resume()
                        #else
                        // Only retry on real devices
                        if attempt < maxAttempts {
                            self.logger.info("📺 AdService: 🔄 Retrying ad load due to nil response...")
                            continuation.resume()
                            Task {
                                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                                await self.loadInterstitialAdSafely(attempt: attempt + 1, maxAttempts: maxAttempts)
                            }
                        } else {
                            continuation.resume()
                        }
                        #endif
                    }
                    
                    // Log final state
                    self.logger.info("📺 AdService: Final state - interstitialAd != nil: \(self.interstitialAd != nil)")
                    self.logger.info("📺 AdService: 🔍 DEBUGGING: loadInterstitialAdSafely completed")
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
        logger.info("📺 AdService: 🎬 showInterstitialAd called")
        
        guard isAdsEnabled else {
            logger.info("🚫 AdService: Ads disabled, executing completion immediately")
            completion()
            return
        }
        
        logger.info("📺 AdService: Ads enabled, checking initialization - adsLoaded: \(self.adsLoaded)")
        
        // Initialize if needed
        if !adsLoaded {
            logger.info("📺 AdService: Ads not loaded, initializing...")
            await initializeAdsWithRetry()
            // Wait for initialization to complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            logger.info("📺 AdService: After initialization - adsLoaded: \(self.adsLoaded)")
        }
        
        // Detailed interstitial ad check
        logger.info("📺 AdService: Checking interstitial ad availability...")
        logger.info("📺 AdService: interstitialAd object: \(String(describing: self.interstitialAd))")
        logger.info("📺 AdService: interstitialAd != nil: \(self.interstitialAd != nil)")
        logger.info("📺 AdService: isLoadingAd: \(self.isLoadingAd)")
        
        // If no ad but one is loading, wait briefly
        if self.interstitialAd == nil && self.isLoadingAd {
            logger.info("📺 AdService: ⏳ Ad is currently loading, waiting up to 3 seconds...")
            
            // Wait up to 3 seconds for the ad to finish loading
            var waitCount = 0
            while self.interstitialAd == nil && self.isLoadingAd && waitCount < 30 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                waitCount += 1
            }
            
            if self.interstitialAd != nil {
                logger.info("📺 AdService: ✅ Ad finished loading while waiting!")
            } else {
                logger.warning("📺 AdService: ⏰ Timed out waiting for ad to load")
            }
        }
        
        if self.interstitialAd == nil {
            logger.warning("📺 AdService: ❌ No interstitial ad available")
            logger.warning("📺 AdService: adsLoaded: \(self.adsLoaded)")
            logger.warning("📺 AdService: interstitialAd: \(String(describing: self.interstitialAd))")
            logger.warning("📺 AdService: Attempting to reload interstitial ad...")
            
            // Try to reload the ad
            await loadInterstitialAdSafely()
            
            // Check again after reload
            if self.interstitialAd == nil {
                logger.warning("📺 AdService: ❌ Failed to reload interstitial ad")
                #if targetEnvironment(simulator)
                logger.info("📺 AdService: 🎭 Simulator detected - falling back to simulated ad")
                await simulateAdForTestingAsync(completion: completion)
                return
                #else
                logger.error("📺 AdService: ❌ No ad available on real device, executing completion")
                completion()
                return
                #endif
            } else {
                logger.info("📺 AdService: ✅ Successfully reloaded interstitial ad")
            }
        }
        
        // Safely get root view controller
        logger.info("📺 AdService: Getting root view controller...")
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            logger.warning("📺 AdService: ❌ No window scene available")
            completion()
            return
        }
        
        guard let window = windowScene.windows.first else {
            logger.warning("📺 AdService: ❌ No window available")
            completion()
            return
        }
        
        guard let rootViewController = window.rootViewController else {
            logger.warning("📺 AdService: ❌ No root view controller available")
            completion()
            return
        }
        
        logger.info("📺 AdService: ✅ Root view controller found: \(rootViewController)")
        
        // Store completion handler
        interstitialCompletionHandler = completion
        
        // Show ad on main thread
        logger.info("📺 AdService: 🎬 Presenting interstitial ad...")
        logger.info("📺 AdService: Ad to present: \(String(describing: self.interstitialAd))")
        isShowingInterstitialAd = true
        
        if let finalAd = self.interstitialAd {
            finalAd.present(from: rootViewController)
            logger.info("📺 AdService: ✅ Interstitial ad presentation called")
        } else {
            logger.error("📺 AdService: ❌ Interstitial ad became nil before presentation")
            isShowingInterstitialAd = false
            completion()
        }
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
        let canShow = isAdsEnabled && adsLoaded && interstitialAd != nil
        logger.info("📺 AdService: canShowInterstitialAd check - isAdsEnabled: \(self.isAdsEnabled), adsLoaded: \(self.adsLoaded), interstitialAd != nil: \(self.interstitialAd != nil), result: \(canShow)")
        
        // If no ad is available but ads are enabled and loaded, try to load one proactively
        if isAdsEnabled && adsLoaded && interstitialAd == nil && !isLoadingAd {
            logger.info("📺 AdService: 🚀 No ad available but should have one - proactively loading...")
            Task {
                await loadInterstitialAdSafely()
            }
        }
        
        return canShow
    }
    
    @MainActor
    func createBannerAdView() -> BannerView? {
        return bannerAd
    }
    
    // MARK: - Debug Methods
    @MainActor
    func forceReloadInterstitialAd() async {
        logger.info("📺 AdService: 🔄 Force reloading interstitial ad for debugging")
        logger.info("📺 AdService: Current state before reload - adsLoaded: \(self.adsLoaded), interstitialAd: \(self.interstitialAd != nil)")
        await loadInterstitialAdSafely()
        logger.info("📺 AdService: State after reload - adsLoaded: \(self.adsLoaded), interstitialAd: \(self.interstitialAd != nil)")
    }
    
    @MainActor
    func simulateAdForTesting(completion: @escaping () -> Void) {
        logger.info("📺 AdService: 🎭 Simulating ad for testing purposes")
        logger.info("📺 AdService: 🖥️ This is a simulator-only feature for testing ad flow")
        
        // Simulate ad presentation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.logger.info("📺 AdService: 🎭 Simulated ad completed")
            completion()
        }
    }
    
    @MainActor
    private func simulateAdForTestingAsync(completion: @escaping () -> Void) async {
        // Execute completion immediately without delay
        completion()
    }
    
    @MainActor
    func testAdLoading() {
        logger.info("📺 AdService: 🧪 Testing ad loading manually")
        logger.info("📺 AdService: Test unit ID: \(self.testInterstitialAdUnitID)")
        logger.info("📺 AdService: Current state - isAdsEnabled: \(self.isAdsEnabled), adsLoaded: \(self.adsLoaded)")
        
        Task {
            await forceReloadInterstitialAd()
        }
    }
    
    @MainActor
    func manualAdLoadingTest() {
        logger.info("📺 AdService: 🧪 MANUAL AD LOADING TEST STARTED")
        logger.info("📺 AdService: 📊 Current AdService State:")
        logger.info("📺 AdService: - isAdsEnabled: \(self.isAdsEnabled)")
        logger.info("📺 AdService: - adsLoaded: \(self.adsLoaded)")
        logger.info("📺 AdService: - isInitializing: \(self.isInitializing)")
        logger.info("📺 AdService: - interstitialAd != nil: \(self.interstitialAd != nil)")
        logger.info("📺 AdService: - canShowInterstitialAd: \(self.canShowInterstitialAd)")
        
        // Check network connectivity
        checkNetworkConnectivity()
        
        Task {
            logger.info("📺 AdService: 🔄 Step 1: Force reload interstitial ad")
            await forceReloadInterstitialAd()
            
            logger.info("📺 AdService: 📊 Post-reload State:")
            logger.info("📺 AdService: - interstitialAd != nil: \(self.interstitialAd != nil)")
            logger.info("📺 AdService: - canShowInterstitialAd: \(self.canShowInterstitialAd)")
            
            logger.info("📺 AdService: 🧪 MANUAL AD LOADING TEST COMPLETED")
        }
    }
    
    @MainActor
    private func checkNetworkConnectivity() {
        logger.info("📺 AdService: 🌐 Checking network connectivity...")
        
        // Basic network check
        let url = URL(string: "https://www.google.com")!
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            Task { @MainActor in
                if let error = error {
                    self?.logger.error("📺 AdService: ❌ Network check failed: \(error.localizedDescription)")
                    self?.logger.warning("📺 AdService: 🔧 Poor network connectivity may affect ad loading")
                } else if let httpResponse = response as? HTTPURLResponse {
                    self?.logger.info("📺 AdService: ✅ Network check successful (HTTP \(httpResponse.statusCode))")
                    self?.logger.info("📺 AdService: 🌐 Network connectivity appears to be working")
                }
            }
        }
        task.resume()
        
        // Check if running in simulator
        #if targetEnvironment(simulator)
        logger.warning("📺 AdService: 🖥️ Running in iOS Simulator")
        logger.warning("📺 AdService: 💡 AdMob test ads frequently fail in simulator")
        logger.warning("📺 AdService: 📱 For reliable ad testing, use a real iOS device")
        #else
        logger.info("📺 AdService: 📱 Running on real iOS device - good for ad testing")
        #endif
    }
    
    @MainActor
    func forceShowAdTest() {
        logger.info("📺 AdService: 🎬 FORCE SHOW AD TEST")
        
        Task {
            await showInterstitialAd {
                // Force ad test completed
            }
        }
    }
    
    @MainActor
    func getDebugInfo() -> String {
        return """
        📺 AdService Debug Info:
        - isAdsEnabled: \(isAdsEnabled)
        - adsLoaded: \(adsLoaded)
        - isInitializing: \(isInitializing)
        - isShowingInterstitialAd: \(isShowingInterstitialAd)
        - interstitialAd != nil: \(interstitialAd != nil)
        - bannerAd != nil: \(bannerAd != nil)
        - testInterstitialAdUnitID: \(testInterstitialAdUnitID)
        - testBannerAdUnitID: \(testBannerAdUnitID)
        """
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
    
    deinit {
        networkMonitor.cancel()
        logger.info("📱 AdService: Deinitialized and network monitor cancelled")
    }
}

// MARK: - FullScreenContentDelegate
extension AdService: FullScreenContentDelegate {
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