import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var showingSignIn = false
    
    private let pages = [
        OnboardingPage(
            title: "今日のごはん、どうしよう？",
            subtitle: "メシセレでサクッと決定！",
            icon: "heart.fill",
            description: "今日のごはん、もう迷わない。\nあなたにぴったりの食事を見つけましょう。",
            color: .blue
        ),
        OnboardingPage(
            title: "簡単3ステップ",
            subtitle: "お食事決定まで",
            icon: "3.circle.fill",
            description: "①好みの条件を設定\n②スピナーを回す\n③おすすめをすぐ表示",
            color: .green
        ),
        OnboardingPage(
            title: "料理も外食も",
            subtitle: "どちらも対応",
            icon: "house.fill",
            description: "今日は料理する？それとも外食？\nその日の気分で選べます。",
            color: .orange
        ),
        OnboardingPage(
            title: "履歴で学習",
            subtitle: "パーソナライゼーション",
            icon: "clock.fill",
            description: "過去の履歴から学習。\nあなた好みをどんどん賢く！",
            color: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Page indicators and buttons
                VStack(spacing: 30) {
                    // Custom page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == currentPage ? 1.2 : 1.0)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    
                    // Navigation buttons
                    HStack(spacing: 20) {
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                Text("戻る")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(Color.blue, lineWidth: 2)
                                    )
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if currentPage < pages.count - 1 {
                                withAnimation {
                                    currentPage += 1
                                }
                            } else {
                                showingSignIn = true
                            }
                        }) {
                            Text(currentPage < pages.count - 1 ? "次へ" : "さっそく始める")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .fill(Color.blue)
                                )
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showingSignIn) {
            SignInView()
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String?
    let icon: String
    let description: String
    let color: Color
    
    init(title: String, subtitle: String? = nil, icon: String, description: String, color: Color) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.description = description
        self.color = color
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .scaleEffect(1.0)
            
            VStack(spacing: 16) {
                // Main Title
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(.horizontal, 30)
                
                // Subtitle (if available)
                if let subtitle = page.subtitle {
                    Text(subtitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 30)
                }
            }
            
            // Description
            Text(page.description)
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
                .lineLimit(nil)
                .lineSpacing(4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
} 