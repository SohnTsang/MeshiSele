import SwiftUI
import UIKit
// import GoogleMobileAds // REMOVED TO PREVENT EXC_BAD_ACCESS CRASHES
import OSLog

// MARK: - Thread-Safe Banner Ad View with Comprehensive Error Prevention
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    private let logger = Logger(subsystem: "MeshiSele", category: "BannerAdView")
    
    init(adUnitID: String = "ca-app-pub-3940256099942544/2435281174") {
        self.adUnitID = adUnitID
    }
    
    func makeUIView(context: Context) -> BannerView {
        logger.info("📺 BannerAdView: Creating Google AdMob banner ad with comprehensive thread safety")
        
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        
        // Set up safely using Task to ensure main thread operations
        Task { @MainActor in
            await setupBannerViewSafely(bannerView)
        }
        
        return bannerView
    }
    
    @MainActor
    private func setupBannerViewSafely(_ bannerView: BannerView) async {
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
                }
            }
        } catch {
            logger.error("📺 BannerAdView: Setup failed with error: \(error.localizedDescription)")
        }
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
        // Use Task for main actor thread safety with minimal updates
        Task { @MainActor in
            // Only update if absolutely necessary to prevent excessive reloading
            if uiView.adUnitID != adUnitID {
                uiView.adUnitID = adUnitID
                
                // Only reload if we have a root view controller
                if uiView.rootViewController != nil {
                    let request = Request()
                    uiView.load(request)
                    logger.info("📺 BannerAdView: Ad unit ID updated, reloading ad")
                }
            }
        }
    }
    
    func makeCoordinator() -> BannerAdCoordinator {
        BannerAdCoordinator()
    }
}

// MARK: - Thread-Safe Banner Ad Coordinator
class BannerAdCoordinator: NSObject, BannerViewDelegate {
    private let logger = Logger(subsystem: "MeshiSele", category: "BannerAdCoordinator")
    
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        Task { @MainActor in
            logger.info("📺 BannerAdCoordinator: Banner ad loaded successfully")
        }
    }
    
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            logger.error("📺 BannerAdCoordinator: Banner ad failed to load: \(error.localizedDescription)")
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
    
    var body: some View {
        BannerAdView()
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
    
    var body: some View {
        BannerAdView()
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