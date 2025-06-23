import SwiftUI

// Theme Colors (consistent with app design)
private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text(LocalizedString("home"))
                }
                .tag(0)
            
            HistoryView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "clock.fill")
                    Text(LocalizedString("history"))
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text(LocalizedString("settings"))
                }
                .tag(2)
        }
        .onAppear {
            setupTabBarAppearance()
        }
        .onChange(of: selectedTab) { _ in
            updateTabBarColor()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Background styling
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowColor = UIColor.clear
        
        // Normal state (unselected tabs)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        // Selected state - will be updated dynamically
        updateTabBarSelectedColor(appearance: appearance)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func updateTabBarColor() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let tabBarController = windowScene.windows.first?.rootViewController as? UITabBarController else {
            return
        }
        
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.shadowColor = UIColor.clear
        
        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        
        updateTabBarSelectedColor(appearance: appearance)
        
        tabBarController.tabBar.standardAppearance = appearance
        tabBarController.tabBar.scrollEdgeAppearance = appearance
    }
    
    private func updateTabBarSelectedColor(appearance: UITabBarAppearance) {
        let selectedColor: UIColor
        
        switch selectedTab {
        case 0: // Home - Orange (warm, inviting for meal decisions)
            selectedColor = UIColor(themeOrange)
        case 1: // History - Teal (cool, organized for data)
            selectedColor = UIColor(themeTeal)
        case 2: // Settings - Orange (consistent primary accent)
            selectedColor = UIColor(themeOrange)
        default:
            selectedColor = UIColor(themeOrange)
        }
        
        // Selected state styling
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 