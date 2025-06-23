import SwiftUI

struct LaunchScreenView: View {
    // Theme color matching #f0c67b
    private let backgroundColor = Color(red: 240/255, green: 198/255, blue: 123/255)
    
    var body: some View {
        ZStack {
            // Background color
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Icon
                Image(systemName: "fork.knife")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                // App Name
                Text(NSLocalizedString("app_name", comment: "App name"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
    }
}

struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
    }
} 