import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showingSignIn = false
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.green.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // App Logo
                VStack(spacing: 16) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(.blue)
                    
                    Text("MeshiSele")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                VStack(spacing: 20) {
                    Text("サインインして始めよう！")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Text("今日のごはん、もう迷わない。\nあなたにぴったりの食事を見つけましょう。")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
                
                VStack(spacing: 16) {
                    // Custom Apple Sign In Button
                    Button(action: {
                        // Clear any previous error messages
                        authService.errorMessage = nil
                        authService.signInWithApple()
                    }) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.title2)
                            Text("Appleでサインイン")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                    .frame(height: 50)
                        .background(Color.black)
                    .cornerRadius(25)
                    }
                    .padding(.horizontal, 40)
                    
                    if authService.isLoading {
                        ProgressView("サインイン中...")
                            .foregroundColor(.secondary)
                    }
                    
                    if let errorMessage = authService.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
                // Privacy Notice
                VStack(spacing: 8) {
                    Text("サインインすることで、")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Button(action: {
                            openPrivacyPolicy()
                        }) {
                            Text("プライバシーポリシー")
                                .font(.caption)
                                .underline()
                                .foregroundColor(.blue)
                        }
                        
                        Text("および")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            openTermsOfService()
                        }) {
                            Text("利用規約")
                                .font(.caption)
                                .underline()
                                .foregroundColor(.blue)
                        }
                        
                        Text("に同意したものとみなされます。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://yourapp.com/privacy") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        guard let url = URL(string: "https://yourapp.com/terms") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
    }
} 