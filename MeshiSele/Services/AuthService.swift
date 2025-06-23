import Foundation
import Firebase
import FirebaseAuth
import AuthenticationServices
import CryptoKit

class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true // Start with loading = true
    @Published var errorMessage: String?
    
    // Unhashed nonce.
    fileprivate var currentNonce: String?
    private var authStateDidChangeListenerHandle: AuthStateDidChangeListenerHandle?
    
    // Thread safety - Use main queue for critical operations
    private let stateQueue = DispatchQueue.main
    
    override init() {
        super.init()
        
        // CRITICAL: Immediately check current auth state
        print("🔐🔐🔐 AuthService: Base initialization complete")
        print("🔐 AuthService: Initial isLoading = \(isLoading)")
        print("🔐 AuthService: Initial isAuthenticated = \(isAuthenticated)")
        
        // Check if Firebase is already configured and check auth state immediately
        print("🔐 AuthService: Scheduling checkInitialAuthState in 0.1 seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            print("🔐 AuthService: About to call checkInitialAuthState...")
            self?.checkInitialAuthState()
        }
    }
    
    deinit {
        print("🔐 AuthService: Deinitializing...")
        
        // CRITICAL: Ensure all operations are cancelled safely on main thread
        DispatchQueue.main.sync {
            cleanupAuthListener()
        }
        
        print("🔐 AuthService: Deinitialized safely")
    }
    
    private func cleanupAuthListener() {
        if let handle = authStateDidChangeListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            authStateDidChangeListenerHandle = nil
        }
    }
    
    // MARK: - Initial State Check
    
    private func checkInitialAuthState() {
        print("🔐🔐🔐 AuthService: checkInitialAuthState called")
        print("🔐 AuthService: Current isLoading = \(isLoading)")
        print("🔐 AuthService: Current isAuthenticated = \(isAuthenticated)")
        
        // Add timeout mechanism - if Firebase is not configured after 3 seconds, proceed with no auth
        print("🔐 AuthService: Setting up 3-second timeout...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { 
                print("🔐 AuthService: Timeout callback - self is nil")
                return 
            }
            if self.isLoading {
                print("🔐🔐🔐 AuthService: Timeout reached, proceeding without authentication")
                self.setIsLoading(false)
                self.setIsAuthenticated(false)
            } else {
                print("🔐 AuthService: Timeout reached but app is no longer loading")
            }
        }
        
        // If Firebase is not yet configured, wait a bit more
        print("🔐 AuthService: Checking if Firebase is configured...")
        guard FirebaseApp.app() != nil else {
            print("🔐🔐🔐 AuthService: Firebase not configured yet, waiting...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("🔐 AuthService: Retrying checkInitialAuthState after 0.5s delay...")
                self?.checkInitialAuthState()
            }
            return
        }
        
        print("🔐 AuthService: ✅ Firebase is configured, checking current user...")
        
        // Check current user immediately
        if let currentFirebaseUser = Auth.auth().currentUser {
            print("🔐🔐🔐 AuthService: Found existing user: \(currentFirebaseUser.uid)")
            loadUserData(userId: currentFirebaseUser.uid)
        } else {
            print("🔐🔐🔐 AuthService: No existing user found")
            setIsLoading(false)
            setIsAuthenticated(false)
        }
    }
    
    // Thread-safe property setters - ONLY use main queue
    private func setCurrentUser(_ user: User?) {
        // CRITICAL: Always use main queue for UI updates
        DispatchQueue.main.async { [weak self] in
            self?.currentUser = user
        }
    }
    
    private func setIsAuthenticated(_ value: Bool) {
        print("🔐🔐🔐 AuthService: setIsAuthenticated called with value: \(value)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🔐 AuthService: About to set isAuthenticated from \(self.isAuthenticated) to \(value)")
            self.isAuthenticated = value
            print("🔐🔐🔐 AuthService: Authentication state set to \(value)")
        }
    }
    
    private func setIsLoading(_ value: Bool) {
        print("🔐🔐🔐 AuthService: setIsLoading called with value: \(value)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🔐 AuthService: About to set isLoading from \(self.isLoading) to \(value)")
            self.isLoading = value
            print("🔐🔐🔐 AuthService: Loading state set to \(value)")
        }
    }
    
    // MARK: - Apple Sign In
    
    func handleAppleSignInAuthorization(_ authorization: ASAuthorization) {
        print("🍎🍎🍎 AuthService: handleAppleSignInAuthorization called")
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            print("🍎 AuthService: Processing ASAuthorizationAppleIDCredential")
            
            guard let nonce = currentNonce else {
                print("❌ AuthService: currentNonce is nil - invalid state")
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "サインイン状態が無効です。アプリを再起動してお試しください。"
                }
                return
            }
            print("🍎 AuthService: ✅ Current nonce is valid")
            
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("❌ AuthService: identityToken is nil")
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "認証トークンを取得できませんでした。再度お試しください。"
                }
                return
            }
            print("🍎 AuthService: ✅ Identity token obtained")
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("❌ AuthService: Failed to convert identity token data to string")
                print("❌ AuthService: Token data length: \(appleIDToken.count)")
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = "認証トークンの変換に失敗しました。再度お試しください。"
                }
                return
            }
            print("🍎 AuthService: ✅ Identity token converted to string (length: \(idTokenString.count))")
            
            print("🔥 AuthService: Creating Firebase credential...")
            
            // Initialize a Firebase credential.
            let credential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idTokenString,
                rawNonce: nonce
            )
            print("🔥 AuthService: ✅ Firebase credential created")
            
            // Sign in with Firebase.
            print("🔥 AuthService: Attempting Firebase sign in...")
            Auth.auth().signIn(with: credential) { [weak self] result, error in
                guard let self = self else { 
                    print("❌ AuthService: self is nil in Firebase completion")
                    return 
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { 
                        print("❌ AuthService: self is nil in main queue completion")
                        return 
                    }
                    
                    if let error = error {
                        print("❌❌❌ Firebase authentication error:")
                        print("❌ Error domain: \(error._domain)")
                        print("❌ Error code: \(error._code)")
                        print("❌ Error description: \(error.localizedDescription)")
                        
                        if let nsError = error as NSError? {
                            print("❌ NSError userInfo: \(nsError.userInfo)")
                        }
                        
                        self.errorMessage = "Firebase認証に失敗しました: \(error.localizedDescription)"
                        return
                    }
                    
                    if let result = result {
                        print("✅✅✅ Firebase sign in successful!")
                        print("✅ User ID: \(result.user.uid)")
                        print("✅ Email: \(result.user.email ?? "nil")")
                        print("✅ Display name: \(result.user.displayName ?? "nil")")
                        print("✅ The auth state listener will handle the rest...")
                        
                        // CRITICAL: Also manually trigger user data loading as backup
                        print("🔥 AuthService: Manually triggering user data load as backup...")
                        self.loadUserData(userId: result.user.uid)
                        // The auth state listener will handle the rest
                    } else {
                        print("❌ Firebase sign in returned nil result and nil error")
                        self.errorMessage = "Firebase認証の結果が無効です。"
                    }
                }
            }
        } else {
            print("❌ AuthService: Authorization credential is not ASAuthorizationAppleIDCredential")
            print("❌ AuthService: Credential type: \(type(of: authorization.credential))")
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "認証情報のタイプが無効です。"
            }
        }
    }
    
    func signInWithApple() {
        print("🍎🍎🍎 AuthService: signInWithApple() called")
        
        // Clear any previous error messages
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = nil
        }
        
        let nonce = randomNonceString()
        currentNonce = nonce
        print("🍎 AuthService: Generated nonce: \(nonce.prefix(10))...")
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        print("🍎 AuthService: Created Apple ID request with scopes: \(request.requestedScopes ?? [])")
        print("🍎 AuthService: Request nonce hash: \(sha256(nonce).prefix(10))...")
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        print("🍎 AuthService: About to perform Apple Sign In requests...")
        authorizationController.performRequests()
        print("🍎 AuthService: performRequests() called successfully")
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            setCurrentUser(nil)
            setIsAuthenticated(false)
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAuthStateListener() {
        // CRITICAL: Only set up listener if not already configured
        guard authStateDidChangeListenerHandle == nil else {
            print("🔐 AuthService: Listener already configured")
            return
        }
        
        print("🔐 AuthService: Setting up auth state listener...")
        
        // Use weak self to prevent retain cycles
        authStateDidChangeListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { 
                print("🔐 AuthService: Auth state listener - self is nil")
                return 
            }
            
            print("🔐🔐🔐 AuthService: Auth state changed!")
            print("🔐 AuthService: User present: \(user != nil)")
            if let user = user {
                print("🔐 AuthService: User ID: \(user.uid)")
                print("🔐 AuthService: User email: \(user.email ?? "nil")")
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { 
                    print("🔐 AuthService: Auth state listener main queue - self is nil")
                    return 
                }
                
                if let user = user {
                    print("🔐🔐🔐 AuthService: User signed in: \(user.uid)")
                    self.loadUserData(userId: user.uid)
                } else {
                    print("🔐🔐🔐 AuthService: User signed out")
                    self.setCurrentUser(nil)
                    self.setIsAuthenticated(false)
                }
            }
        }
    }
    
    private func loadUserData(userId: String) {
        print("🔐🔐🔐 AuthService: loadUserData called for user: \(userId)")
        setIsLoading(true)
        
        print("🔐 AuthService: Calling FirebaseService.getUser...")
        // Use weak self to prevent retain cycles
        FirebaseService.shared.getUser(id: userId) { [weak self] user, error in
            guard let self = self else { 
                print("🔐 AuthService: loadUserData completion - self is nil")
                return 
            }
            
            print("🔐🔐🔐 AuthService: getUser completion called")
            print("🔐 AuthService: User found: \(user != nil)")
            print("🔐 AuthService: Error: \(error?.localizedDescription ?? "nil")")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { 
                    print("🔐 AuthService: loadUserData main queue - self is nil")
                    return 
                }
                
                print("🔐🔐🔐 AuthService: Setting isLoading to false")
                self.setIsLoading(false)
                
                if let user = user {
                    print("🔐🔐🔐 AuthService: User data loaded: \(user.displayName)")
                    print("🔐 AuthService: Setting currentUser and isAuthenticated to true")
                    self.setCurrentUser(user)
                    self.setIsAuthenticated(true)
                } else {
                    print("🔐🔐🔐 AuthService: No existing user found, creating new user profile")
                    self.createNewUser(userId: userId)
                }
            }
        }
    }
    
    private func createNewUser(userId: String) {
        print("🔐🔐🔐 AuthService: createNewUser called for user: \(userId)")
        
        guard let firebaseUser = Auth.auth().currentUser else { 
            print("❌ AuthService: No current Firebase user found")
            return 
        }
        
        let displayName = firebaseUser.displayName ?? "ユーザー"
        let email = firebaseUser.email ?? ""
        
        print("🔐 AuthService: Creating user with displayName: '\(displayName)', email: '\(email)'")
        let newUser = User(id: userId, displayName: displayName, email: email)
        
        print("🔐 AuthService: Calling FirebaseService.createUser...")
        // Use weak self to prevent retain cycles
        FirebaseService.shared.createUser(newUser) { [weak self] error in
            guard let self = self else { 
                print("🔐 AuthService: createNewUser completion - self is nil")
                return 
            }
            
            print("🔐🔐🔐 AuthService: createUser completion called")
            print("🔐 AuthService: Error: \(error?.localizedDescription ?? "nil")")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { 
                    print("🔐 AuthService: createNewUser main queue - self is nil")
                    return 
                }
                
                if error == nil {
                    print("🔐🔐🔐 AuthService: New user created successfully")
                    print("🔐 AuthService: Setting currentUser and isAuthenticated to true")
                    self.setCurrentUser(newUser)
                    self.setIsAuthenticated(true)
                } else {
                    print("❌❌❌ AuthService: Failed to create user: \(error?.localizedDescription ?? "unknown")")
                    // Even if user creation fails, we can still proceed with authentication
                    print("🔐 AuthService: Proceeding with authentication despite user creation failure")
                    self.setCurrentUser(newUser)
                    self.setIsAuthenticated(true)
                }
            }
        }
    }
    
    // MARK: - Helper Methods for Apple Sign In
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError(
                        "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
                    )
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    // Call this after Firebase is configured in AppDelegate
    func configureAuthService() {
        print("🔐🔐🔐 AuthService: configureAuthService called")
        
        // Only set up listener if Firebase is configured
        guard FirebaseApp.app() != nil else {
            print("🔐🔐🔐 AuthService: Firebase not configured, cannot set up listener")
            return
        }
        
        print("🔐 AuthService: Firebase is configured, setting up auth state listener...")
        setupAuthStateListener()
        print("🔐🔐🔐 AuthService: Auth service configuration complete")
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        print("🍎🍎🍎 AuthService: didCompleteWithAuthorization called")
        print("🍎 AuthService: Authorization credential type: \(type(of: authorization.credential))")
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            print("🍎 AuthService: ✅ Successfully got ASAuthorizationAppleIDCredential")
            print("🍎 AuthService: User identifier: \(appleIDCredential.user)")
            print("🍎 AuthService: Full name: \(appleIDCredential.fullName?.description ?? "nil")")
            print("🍎 AuthService: Email: \(appleIDCredential.email ?? "nil")")
            print("🍎 AuthService: Identity token present: \(appleIDCredential.identityToken != nil)")
            print("🍎 AuthService: Authorization code present: \(appleIDCredential.authorizationCode != nil)")
            
            handleAppleSignInAuthorization(authorization)
        } else {
            print("❌ AuthService: Failed to cast credential to ASAuthorizationAppleIDCredential")
            print("❌ AuthService: Actual credential type: \(type(of: authorization.credential))")
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "サインイン認証情報が無効です。再度お試しください。"
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌❌❌ AuthService: didCompleteWithError called")
        print("❌ AuthService: Error domain: \(error._domain)")
        print("❌ AuthService: Error code: \(error._code)")
        print("❌ AuthService: Error description: \(error.localizedDescription)")
        
        // Handle different types of Apple Sign In errors
        if let authError = error as? ASAuthorizationError {
            print("❌ AuthService: ASAuthorizationError code: \(authError.code.rawValue)")
            print("❌ AuthService: ASAuthorizationError description: \(authError.localizedDescription)")
            
            DispatchQueue.main.async { [weak self] in
                switch authError.code {
                case .canceled:
                    // User canceled - don't show error message
                    print("🍎 User canceled Apple Sign In")
                    return
                case .unknown:
                    self?.errorMessage = "サインインに失敗しました。時間をおいて再度お試しください。"
                case .invalidResponse:
                    self?.errorMessage = "サインインの応答が無効です。再度お試しください。"
                case .notHandled:
                    self?.errorMessage = "サインインを処理できませんでした。再度お試しください。"
                case .failed:
                    self?.errorMessage = "サインインに失敗しました。時間をおいて再度お試しください。"
                case .notInteractive:
                    self?.errorMessage = "サインインが利用できません。設定を確認してください。"
                case .matchedExcludedCredential:
                    self?.errorMessage = "このアカウントでのサインインは制限されています。"
                case .credentialImport:
                    self?.errorMessage = "認証情報のインポートに失敗しました。"
                case .credentialExport:
                    self?.errorMessage = "認証情報のエクスポートに失敗しました。"
                @unknown default:
                    self?.errorMessage = "サインインに失敗しました。時間をおいて再度お試しください。"
                }
            }
        } else {
            print("❌ AuthService: Non-ASAuthorizationError: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "サインインに失敗しました。時間をおいて再度お試しください。"
            }
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        print("🍎🍎🍎 AuthService: presentationAnchor called")
        
        // Get the first window scene
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            print("❌ AuthService: No window scene found")
            fatalError("No window scene available for presentation")
        }
        
        guard let window = windowScene.windows.first else {
            print("❌ AuthService: No window found in scene")
            fatalError("No window available for presentation")
        }
        
        print("🍎 AuthService: ✅ Found presentation anchor window")
        return window
    }
} 