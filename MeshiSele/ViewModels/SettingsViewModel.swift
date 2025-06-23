import Foundation
import Combine
import UserNotifications
import UIKit

class SettingsViewModel: ObservableObject {
    @Published var user: User?
    @Published var appVersion: String = "1.0"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showSignOutAlert: Bool = false

    @Published var darkModeEnabled: Bool = false
    @Published var displayName: String = ""
    @Published var email: String = ""
    
    // Settings state
    @Published var isEditingDisplayName: Bool = false
    @Published var tempDisplayName: String = ""
    
    private var cancellables: Set<AnyCancellable> = []
    private let authService = AuthService.shared
    private let firebaseService = FirebaseService.shared
    
    // Thread safety
    private let stateQueue = DispatchQueue(label: "com.meshisele.settingsviewmodel.state", qos: .userInitiated)
    
    init() {
        setupSubscriptions()
        loadUserData()
        loadDarkModePreference()
        loadAppVersion()
    }
    
    deinit {
        // Cancel all subscriptions to prevent retain cycles
        cancellables.removeAll()
    }
    
    // Thread-safe property setters
    private func setUser(_ user: User?) {
        DispatchQueue.main.async { [weak self] in
            self?.user = user
        }
    }
    
    private func setIsLoading(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = value
        }
    }
    
    private func setErrorMessage(_ message: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
        }
    }
    

    
    private func setDisplayName(_ name: String) {
        DispatchQueue.main.async { [weak self] in
            self?.displayName = name
        }
    }
    
    private func setEmail(_ email: String) {
        DispatchQueue.main.async { [weak self] in
            self?.email = email
        }
    }
    
    private func setupSubscriptions() {
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.setUser(user)
                self?.setDisplayName(user?.displayName ?? "")
                self?.setEmail(user?.email ?? "")
            }
            .store(in: &cancellables)
    }
    
    private func loadUserData() {
        user = authService.currentUser
        if let user = user {
            displayName = user.displayName
            email = user.email
        }
    }
    
    private func loadAppVersion() {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            appVersion = version
        }
    }
    
    private func loadDarkModePreference() {
        // Check if user has explicitly saved a dark mode preference
        let hasSavedPreference = UserDefaults.standard.object(forKey: "darkModeEnabled") != nil
        
        if hasSavedPreference {
            // Load the saved preference
            darkModeEnabled = UserDefaults.standard.bool(forKey: "darkModeEnabled")
        } else {
            // No saved preference - default to white mode (false)
            darkModeEnabled = false
            UserDefaults.standard.set(false, forKey: "darkModeEnabled")
        }
    }
    
    // MARK: - Dark Mode Settings
    
    func updateDarkModePreference(enabled: Bool) {
        print("🌙 SettingsViewModel: Updating dark mode preference to: \(enabled)")
        darkModeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "darkModeEnabled")
        applyDarkModePreference(enabled ? .dark : .light)
    }
    
    private func applyDarkModePreference(_ style: UIUserInterfaceStyle) {
        DispatchQueue.main.async {
            print("🌙 SettingsViewModel: Applying interface style: \(style)")
            
            // Apply to all windows
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { 
                print("🌙 SettingsViewModel: No window scene found")
                return 
            }
            
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
                print("🌙 SettingsViewModel: Applied style \(style) to window")
            }
        }
    }
    
    // MARK: - User Profile Management
    
    func startEditingDisplayName() {
        tempDisplayName = displayName
        isEditingDisplayName = true
    }
    
    func saveDisplayName() {
        guard var user = user, !tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cancelEditingDisplayName()
            return
        }
        
        setIsLoading(true)
        setErrorMessage(nil)
        
        user.displayName = tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        firebaseService.updateUser(user) { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                self?.setIsLoading(false)
                
                if let error = error {
                    self?.setErrorMessage(error.localizedDescription)
                } else {
                    self?.setDisplayName(user.displayName)
                    self?.authService.currentUser = user
                    self?.isEditingDisplayName = false
                }
            }
        }
    }
    
    func cancelEditingDisplayName() {
        tempDisplayName = ""
        isEditingDisplayName = false
    }
    

    
    // MARK: - Default Settings Management
    
    func resetDefaultSettings() {
        guard var user = user else { return }
        
        isLoading = true
        errorMessage = nil
        
        user.defaultPreferences = User.DefaultPreferences()
        
        firebaseService.updateUser(user) { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.authService.currentUser = user
                }
            }
        }
    }
    
    // MARK: - Sign Out
    
    func requestSignOut() {
        showSignOutAlert = true
    }
    
    func confirmSignOut() {
        authService.signOut()
        showSignOutAlert = false
    }
    
    func cancelSignOut() {
        showSignOutAlert = false
    }
    
    // MARK: - External Links
    
    func openPrivacyPolicy() {
        guard let url = URL(string: "https://yourapp.com/privacy") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    func openTermsOfService() {
        guard let url = URL(string: "https://yourapp.com/terms") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    func contactSupport() {
        let email = "support@yourapp.com"
        let subject = "MealDecider App - お問い合わせ"
        let body = "お問い合わせ内容をご記入ください。\n\nApp Version: \(appVersion)\nUser ID: \(user?.id ?? "Unknown")"
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Utility Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    var formattedAppVersion: String {
        return String(format: NSLocalizedString("app_version", comment: "App version"), appVersion)
    }
} 