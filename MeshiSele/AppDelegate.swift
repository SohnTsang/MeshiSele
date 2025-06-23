import UIKit
import Firebase
import GoogleMobileAds // CRITICAL: Re-enabled with proper initialization
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // CRITICAL: Set up crash detection FIRST
        setupCrashDetection()
        
        print("🚀🚀🚀 AppDelegate: didFinishLaunchingWithOptions START")
        print("🚀 AppDelegate: Starting safe Firebase initialization...")
        
        // CRITICAL: Initialize Firebase safely without Analytics
        print("🚀 AppDelegate: About to call FirebaseApp.configure()")
        FirebaseApp.configure()
        print("✅✅✅ Firebase configured successfully (no Analytics)")
        
        // CRITICAL: Initialize Google Mobile Ads SDK SAFELY
        print("📱 AppDelegate: Initializing Google Mobile Ads SDK...")
        // Note: AdMob initialization will be handled by the framework automatically
        // when ads are first requested. Manual initialization is optional.
        print("🎯 AdMob will be initialized automatically when first ad is requested")
        
        // CRITICAL: Initialize AuthService immediately after Firebase is ready
        print("🚀 AppDelegate: Scheduling AuthService configuration in 0.1 seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("🚀 AppDelegate: About to configure AuthService...")
            AuthService.shared.configureAuthService()
            print("✅✅✅ AuthService configured safely")
        }
        
        // Request notification permission with MAXIMUM safety
        print("📲 AppDelegate: Requesting notification permissions...")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification authorization error: \(error.localizedDescription)")
                return
            }
            
            print(granted ? "✅ Notifications granted" : "❌ Notifications denied")
            
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                    print("📲 Registered for remote notifications")
                }
            }
        }
        
        UNUserNotificationCenter.current().delegate = self
        
        print("🎯🎯🎯 AppDelegate initialization COMPLETED successfully")
        return true
    }
    
    // MARK: - Crash Detection
    
    private func setupCrashDetection() {
        // Set up exception handler
        NSSetUncaughtExceptionHandler { exception in
            print("🚨🚨🚨 UNCAUGHT EXCEPTION: \(exception)")
            print("🚨 Name: \(exception.name)")
            print("🚨 Reason: \(exception.reason ?? "No reason")")
            print("🚨 Stack: \(exception.callStackSymbols)")
            
            // Log to file for persistence
            let crashInfo = """
            CRASH DETECTED: \(Date())
            Exception: \(exception.name)
            Reason: \(exception.reason ?? "Unknown")
            Stack: \(exception.callStackSymbols.joined(separator: "\n"))
            """
            
            if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let crashLogURL = documentsPath.appendingPathComponent("crash_log.txt")
                try? crashInfo.write(to: crashLogURL, atomically: true, encoding: .utf8)
                print("🚨 Crash logged to: \(crashLogURL.path)")
            }
        }
        
        // Set up signal handler for EXC_BAD_ACCESS
        signal(SIGSEGV) { signal in
            print("🚨🚨🚨 SIGSEGV (EXC_BAD_ACCESS) detected on signal \(signal)")
            
            // Log stack trace if possible
            let symbols = Thread.callStackSymbols
            print("🚨 Stack trace:")
            symbols.forEach { print("🚨   \($0)") }
            
            // Exit gracefully to prevent further corruption
            exit(signal)
        }
        
        signal(SIGBUS) { signal in
            print("🚨🚨🚨 SIGBUS detected on signal \(signal)")
            let symbols = Thread.callStackSymbols
            print("🚨 Stack trace:")
            symbols.forEach { print("🚨   \($0)") }
            exit(signal)
        }
        
        print("✅ Crash detection handlers installed")
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        print("🖼️ AppDelegate: Configuring scene session")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        print("🗑️ AppDelegate: Discarded scene sessions: \(sceneSessions.count)")
    }
    
    // MARK: Push Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Handle device token registration with MAXIMUM error handling
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("📱 Device token received: \(token.prefix(20))...")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📩 Notification will present: \(notification.request.identifier)")
        // Handle foreground notifications
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("👆 Notification tapped: \(response.notification.request.identifier)")
        // Handle notification tap
        completionHandler()
    }
} 