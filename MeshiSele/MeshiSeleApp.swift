import SwiftUI
import Firebase

@main
struct MeshiSeleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
        print("📱📱📱 MeshiSeleApp: init() called")
        
        // Configure debug settings to reduce simulator noise
        DebugConfig.setupGlobalConfiguration()
        
        // Apply dark mode preference immediately on app startup
        loadAndApplyDarkModePreference()
    }
    
    var body: some Scene {
        print("📱📱📱 MeshiSeleApp: body getter called")
        return WindowGroup {
            ContentView()
                .onAppear {
                    print("📱📱📱 MeshiSeleApp: WindowGroup onAppear called")
                }
        }
    }
    
    // Load and apply dark mode preference at app startup using existing boolean system
    private func loadAndApplyDarkModePreference() {
        // Check if user has a saved dark mode preference
        let hasSavedPreference = UserDefaults.standard.object(forKey: "darkModeEnabled") != nil
        
        let darkModeEnabled: Bool
        if hasSavedPreference {
            darkModeEnabled = UserDefaults.standard.bool(forKey: "darkModeEnabled")
            print("🌙 MeshiSeleApp: Applying saved dark mode preference on startup: \(darkModeEnabled ? "dark" : "light")")
        } else {
            // Default to white mode (light mode) if no preference is saved
            darkModeEnabled = false
            UserDefaults.standard.set(false, forKey: "darkModeEnabled")
            print("🌙 MeshiSeleApp: No saved preference, defaulting to light mode")
        }
        
        let style: UIUserInterfaceStyle = darkModeEnabled ? .dark : .light
        
        // Apply to the window scene when available
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                // If no window scene yet, try again after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.applyInterfaceStyle(style)
                }
                return
            }
            
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
                print("🌙 MeshiSeleApp: Applied interface style \(style) to window")
            }
        }
    }
    
    private func applyInterfaceStyle(_ style: UIUserInterfaceStyle) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("🌙 MeshiSeleApp: Still no window scene available")
            return
        }
        
        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = style
            print("🌙 MeshiSeleApp: Applied delayed interface style \(style) to window")
        }
    }
} 