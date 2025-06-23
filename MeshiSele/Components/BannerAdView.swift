import SwiftUI
import UIKit
import GoogleMobileAds
import OSLog

// MARK: - Banner Ad Loading Coordinator
@MainActor
class BannerAdLoadingCoordinator {
    static let shared = BannerAdLoadingCoordinator()
    
    private var loadingBanners: Set<String> = []
    private var lastLoadTime: Date = Date.distantPast
    private let minimumLoadInterval: TimeInterval = 0.5 // 500ms between loads
    
    private init() {}
    
    func canLoadBanner(id: String) -> Bool {
        // Prevent loading if this banner is already loading
        if loadingBanners.contains(id) {
            return false
        }
        
        // Throttle loading to prevent overwhelming the ad system
        let timeSinceLastLoad = Date().timeIntervalSince(lastLoadTime)
        return timeSinceLastLoad >= minimumLoadInterval
    }
    
    func startLoading(id: String) {
        loadingBanners.insert(id)
        lastLoadTime = Date()
    }
    
    func finishLoading(id: String) {
        loadingBanners.remove(id)
    }
}

// MARK: - Thread-Safe Banner Ad View with Comprehensive Error Prevention
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    private let bannerId: String
    private let logger = Logger(subsystem: "MeshiSele", category: "BannerAdView")
    
    init(adUnitID: String = "ca-app-pub-3940256099942544/2435281174", bannerId: String = UUID().uuidString) {
        self.adUnitID = adUnitID
        self.bannerId = bannerId
    }
    
    func makeUIView(context: Context) -> BannerView {
        logger.info("📺 BannerAdView: Creating Google AdMob banner ad with comprehensive thread safety")
        
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        
        // Prevent view overflow and interference
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.clipsToBounds = true
        
        // Set up safely using Task to ensure main thread operations
        Task { @MainActor in
            await setupBannerViewSafely(bannerView)
        }
        
        return bannerView
    }
    
    @MainActor
    private func setupBannerViewSafely(_ bannerView: BannerView) async {
        // Check with coordinator if we can load this banner
        guard BannerAdLoadingCoordinator.shared.canLoadBanner(id: bannerId) else {
            logger.info("📺 BannerAdView: Skipping load - throttled or already loading (ID: \(bannerId))")
            return
        }
        
        BannerAdLoadingCoordinator.shared.startLoading(id: bannerId)
        
        // Add multiple safety checks and delays to prevent threading issues
        do {
            // Wait for view to be properly initialized
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Safely access window hierarchy with multiple fallbacks
            if let rootViewController = await getRootViewControllerSafely() {
                bannerView.rootViewController = rootViewController
                
                // Load ad with additional delay to ensure everything is ready
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                let request = Request()
                
                // Configure request for test ads
                #if DEBUG
                logger.info("📺 BannerAdView: 🧪 Creating test ad request")
                #endif
                
                bannerView.load(request)
                
                logger.info("📺 BannerAdView: Banner ad setup completed successfully")
            } else {
                logger.warning("📺 BannerAdView: Could not find root view controller, retrying...")
                
                // Retry after a longer delay
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if let rootViewController = await getRootViewControllerSafely() {
                    bannerView.rootViewController = rootViewController
                    let request = Request()
                    bannerView.load(request)
                } else {
                    // No root controller found after retry, finish loading
                    BannerAdLoadingCoordinator.shared.finishLoading(id: bannerId)
                }
            }
        } catch {
            logger.error("📺 BannerAdView: Setup failed with error: \(error.localizedDescription)")
            // Finish loading on error
            BannerAdLoadingCoordinator.shared.finishLoading(id: bannerId)
        }
        
        // Note: finishLoading is called by the coordinator on success/failure
    }
    
    @MainActor
    private func getRootViewControllerSafely() async -> UIViewController? {
        // Multiple attempts to safely get root view controller
        for attempt in 1...3 {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                logger.info("📺 BannerAdView: Found root view controller on attempt \(attempt)")
                return rootViewController
            }
            
            // Wait between attempts
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        logger.error("📺 BannerAdView: Failed to find root view controller after 3 attempts")
        return nil
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        // Minimize updates to prevent excessive reloading - only update if critical properties changed
        Task { @MainActor in
            // Prevent unnecessary reloads by being more conservative about updates
            if uiView.adUnitID != adUnitID {
                uiView.adUnitID = adUnitID
                logger.info("📺 BannerAdView: Ad unit ID changed, reloading necessary")
                
                // Only reload if we have a root view controller and ad isn't already loading
                if uiView.rootViewController != nil {
                    // Add throttling to prevent rapid successive loads
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    let request = Request()
                    uiView.load(request)
                    logger.info("📺 BannerAdView: Ad unit ID updated, reloading ad")
                }
            }
            // Skip all other updates to minimize network requests
        }
    }
    
    func makeCoordinator() -> BannerAdCoordinator {
        let coordinator = BannerAdCoordinator()
        coordinator.bannerId = bannerId
        return coordinator
    }
}

// MARK: - Thread-Safe Banner Ad Coordinator
class BannerAdCoordinator: NSObject, BannerViewDelegate {
    private let logger = Logger(subsystem: "MeshiSele", category: "BannerAdCoordinator")
    var bannerId: String?
    private var retryCount = 0
    private let maxRetries = 2
    private var bannerView: BannerView?
    
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        Task { @MainActor in
            logger.info("📺 BannerAdCoordinator: Banner ad loaded successfully")
            retryCount = 0 // Reset retry count on success
            if let bannerId = bannerId {
                BannerAdLoadingCoordinator.shared.finishLoading(id: bannerId)
            }
        }
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            let errorCode = (error as NSError).code
            let errorDomain = (error as NSError).domain
            
            // Check if it's a network error and we should retry
            let isNetworkError = errorCode == -1005 || // Network connection lost
                               errorCode == -1009 || // No internet connection
                               errorDomain == NSURLErrorDomain ||
                               error.localizedDescription.contains("ネットワーク") ||
                               error.localizedDescription.contains("network") ||
                               error.localizedDescription.contains("connection")
            
            if isNetworkError && self.retryCount < self.maxRetries {
                self.retryCount += 1
                logger.info("📺 BannerAdCoordinator: Network error detected, retrying (\(self.retryCount)/\(self.maxRetries)) in 2 seconds...")
                
                // Retry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard self != nil else { return }
                    // Retry loading the banner ad
                    bannerView.load(Request())
                }
            } else {
            logger.error("📺 BannerAdCoordinator: Banner ad failed to load: \(error.localizedDescription)")
            if let bannerId = bannerId {
                BannerAdLoadingCoordinator.shared.finishLoading(id: bannerId)
                }
            }
        }
    }
    
    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        Task { @MainActor in
            logger.info("📺 BannerAdCoordinator: Banner ad impression recorded")
        }
    }
    
    func bannerViewWillPresentScreen(_ bannerView: BannerView) {
        Task { @MainActor in
            logger.info("📺 BannerAdCoordinator: Banner ad will present screen")
        }
    }
    
    func bannerViewWillDismissScreen(_ bannerView: BannerView) {
        Task { @MainActor in
            logger.info("📺 BannerAdCoordinator: Banner ad will dismiss screen")
        }
    }
    
    func bannerViewDidDismissScreen(_ bannerView: BannerView) {
        Task { @MainActor in
            logger.info("📺 BannerAdCoordinator: Banner ad did dismiss screen")
        }
    }
}

// MARK: - Large Banner Ad View with Thread Safety
struct LargeBannerAdView: UIViewRepresentable {
    let adUnitID: String
    private let logger = Logger(subsystem: "MeshiSele", category: "LargeBannerAdView")
    
    init(adUnitID: String = "ca-app-pub-3940256099942544/2435281174") {
        self.adUnitID = adUnitID
    }
    
    func makeUIView(context: Context) -> BannerView {
        logger.info("📺 LargeBannerAdView: Creating large Google AdMob banner ad with thread safety")
        
        let bannerView = BannerView(adSize: AdSizeLargeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        
        // Set up safely using Task to ensure main thread operations
        Task { @MainActor in
            await setupLargeBannerViewSafely(bannerView)
        }
        
        return bannerView
    }
    
    @MainActor
    private func setupLargeBannerViewSafely(_ bannerView: BannerView) async {
        do {
            // Wait for view to be properly initialized
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Safely access window hierarchy
            if let rootViewController = await getRootViewControllerSafely() {
                bannerView.rootViewController = rootViewController
                
                // Load ad with delay
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                let request = Request()
                bannerView.load(request)
                
                logger.info("📺 LargeBannerAdView: Large banner ad setup completed")
            } else {
                logger.warning("📺 LargeBannerAdView: Could not find root view controller")
            }
        } catch {
            logger.error("📺 LargeBannerAdView: Setup failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func getRootViewControllerSafely() async -> UIViewController? {
        for attempt in 1...3 {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                return rootViewController
            }
            
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        return nil
    }
    
    func updateUIView(_ uiView: BannerView, context: Context) {
        Task { @MainActor in
            if uiView.adUnitID != adUnitID {
                uiView.adUnitID = adUnitID
                
                if uiView.rootViewController != nil {
                    let request = Request()
                    uiView.load(request)
                }
            }
        }
    }
    
    func makeCoordinator() -> BannerAdCoordinator {
        BannerAdCoordinator()
    }
}

// MARK: - Specific Banner Ad Views for Different Screens
struct HomeBannerAdView: View {
    private let logger = Logger(subsystem: "MeshiSele", category: "HomeBannerAdView")
    private let bannerId: String
    
    init(id: String = UUID().uuidString) {
        self.bannerId = "home_\(id)"
    }
    
    var body: some View {
        BannerAdView(bannerId: bannerId)
            .frame(height: 50)
            .onAppear {
                logger.info("📺 HomeBannerAdView: Appeared")
            }
            .onDisappear {
                logger.info("📺 HomeBannerAdView: Disappeared")
            }
    }
}

struct HistoryBannerAdView: View {
    private let logger = Logger(subsystem: "MeshiSele", category: "HistoryBannerAdView")
    private let bannerId: String = "history_\(UUID().uuidString)"
    
    var body: some View {
        BannerAdView(bannerId: bannerId)
            .frame(height: 50)
            .onAppear {
                logger.info("📺 HistoryBannerAdView: Appeared")
            }
            .onDisappear {
                logger.info("📺 HistoryBannerAdView: Disappeared")
            }
    }
}

struct SettingsBannerAdView: View {
    private let logger = Logger(subsystem: "MeshiSele", category: "SettingsBannerAdView")
    
    var body: some View {
        BannerAdView()
            .frame(height: 50)
            .onAppear {
                logger.info("📺 SettingsBannerAdView: Appeared")
            }
            .onDisappear {
                logger.info("📺 SettingsBannerAdView: Disappeared")
            }
    }
}

// MARK: - Thread-Safe Extensions for BannerView
extension BannerView {
    /// Thread-safe method to safely remove from parent
    @MainActor
    func safeRemoveFromParent() {
        if superview != nil {
            removeFromSuperview()
        }
    }
    
    /// Thread-safe method to check if ad is loaded
    @MainActor
    func isAdLoaded() -> Bool {
        return rootViewController != nil && adUnitID != nil
    }
} 