import SwiftUI

// Custom localization manager to ensure Japanese strings are used
class LocalizationManager {
    static let shared = LocalizationManager()
    
    private let japaneseStrings: [String: String] = [
        "add_to_favorites": "お気に入りに追加",
        "favorited": "お気に入り済み",
        "share_on_sns": "SNSでシェア",
        "popularity_count": "%d人がこれを選びました",
        "popularity_label": "人気",
        "person_count_adjustment": "人数調整",
        "person_count_display": "%d人前",
        "rate_recipe": "このレシピを評価する",
        "rate_recipe_question": "このレシピはいかがでしたか？",
        "ingredients": "材料",
        "instructions": "作り方",
        "nutrition_info": "栄養成分",
        "nutrition_per_serving": "1人前あたりの栄養成分",
        "calories": "エネルギー",
        "protein": "タンパク質",
        "fat": "脂質",
        "carbs": "炭水化物",
        "fiber": "食物繊維",
        "sugar": "糖質",
        "sodium": "ナトリウム",
        "cholesterol": "コレステロール",
        "share": "シェア",
        "decide": "決める",
        "loading": "読み込み中",
        "error": "エラー",
        "ok": "OK",
        "cancel": "キャンセル",
        "view_details": "詳細を見る",
        
        // Diet tags
        "healthy": "ヘルシー", 
        "vegetarian": "ベジタリアン",
        "meat": "肉食",
        "gluten_free": "グルテンフリー",
        
        // Budget and time constraints
        "no_limit": "指定なし",
        "no_time_limit": "指定なし",
        "under_500": "500円以下",
        "500_1000": "500〜1000円",
        "1000_1500": "1000〜1500円",
        "ten_min": "10分以内",
        "thirty_min": "30分以内",
        "sixty_min": "60分以内",
        
        // Cuisine types
        "washoku": "和食",
        "yoshoku": "洋食", 
        "chuka": "中華",
        "italian": "イタリアン",
        "all": "すべて",
        "other": "その他",
        
        // Tab Bar
        "home": "ホーム",
        "history": "履歴",
        "settings": "設定",
        
        // General
        "done": "完了",
        "save_rating": "評価を保存",
        "not_rated": "未評価",
        "recommended_recipe": "おすすめレシピ",
        "recommended_restaurant": "おすすめレストラン",
        "date_format": "yyyy年M月d日",
        "cook": "料理する",
        "eat_out": "外食",
        "app_version": "アプリバージョン: %@",
        
        // Form fields
        "add_ingredients_required": "食材を追加してください",
        "no_recipe_found": "レシピが見つかりませんでした",
        "no_restaurant_found": "レストランが見つかりませんでした",
        "lunch_reminder": "お昼ご飯の時間です！",
        "dinner_reminder": "夕ご飯の時間です！",
        
        // Filter cards
        "select_meal_mode": "料理モードを選択",
        "select_diet_type": "ダイエットタイプを選択",
        "select_cuisine": "料理ジャンルを選択",
        "random_or_specify": "おまかせ／食材を指定",
        "random": "おまかせ",
        "specify_ingredients": "食材を指定",
        "enter_ingredients": "食材を入力",
        "add": "追加",
        "exclude_ingredients": "除外する食材",
        "one_serving": "1人前",
        "two_servings": "2人前",
        "three_four_servings": "3〜4人前",
        "five_plus_servings": "5人前以上",
        "servings": "人数",
        "budget": "予算",
        "cooking_time": "調理時間",
        "receive_reminders": "リマインダーを受け取る",
        "receive_notifications": "通知を受け取る",
        "notification_settings_note": "食事の時間にお知らせします",
        
        // Restaurant detail
        "directions": "道順",
        "route_guidance": "経路案内",
        "open_in_apple_maps": "Apple Mapsで開く",
        "open_in_google_maps": "Google Mapsで開く",
        "copy_address": "住所をコピー",
        "share_restaurant": "レストランをシェア",
        "copy_restaurant_info": "レストラン情報をコピー",
        
        // Recipe detail  
        "share_recipe": "レシピをシェア",
        "copy_link": "リンクをコピー",
        "rate_this_recipe": "このレシピを評価",
        "thank_you_for_rating": "評価ありがとうございます"
    ]
    
    func localizedString(for key: String, defaultValue: String? = nil) -> String {
        // First try to get from Japanese strings
        if let japaneseString = japaneseStrings[key] {
            return japaneseString
        }
        
        // Fallback to NSLocalizedString
        let localized = NSLocalizedString(key, comment: "")
        if localized != key {
            return localized
        }
        
        // Last resort: return default value or key
        return defaultValue ?? key
    }
}

// Global convenience function
func LocalizedString(_ key: String, defaultValue: String? = nil) -> String {
    return LocalizationManager.shared.localizedString(for: key, defaultValue: defaultValue)
}

struct ContentView: View {
    @ObservedObject private var authService = AuthService.shared
    @ObservedObject private var locationManager = LocationManager.shared
    
    init() {
        print("🏠🏠🏠 ContentView: init() called")
        print("🏠 ContentView: Initial authService.isLoading = \(AuthService.shared.isLoading)")
        print("🏠 ContentView: Initial authService.isAuthenticated = \(AuthService.shared.isAuthenticated)")
    }
    
    var body: some View {
        Group {
            if authService.isLoading {
                LoadingView()
                    .onAppear {
                        print("🏠🏠🏠 ContentView: LoadingView appeared")
                        print("🏠 ContentView: ✅ Showing LoadingView")
                    }
            } else if authService.isAuthenticated {
                MainTabView()
                    .environmentObject(authService)
                    .environmentObject(locationManager)
                    .onAppear {
                        print("🏠🏠🏠 ContentView: MainTabView appeared")
                        print("🏠 ContentView: ✅ Showing MainTabView")
                        
                        // Debug Firebase query
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            print("🔧 DEBUG: Triggering Firebase debug query...")
                            RecipeService.shared.debugFirebaseQuery()
                        }
                    }
            } else {
                OnboardingView()
                    .environmentObject(authService)
                    .environmentObject(locationManager)
                    .onAppear {
                        print("🏠🏠🏠 ContentView: OnboardingView appeared")
                        print("🏠 ContentView: ✅ Showing OnboardingView")
                    }
            }
        }
        .onAppear {
            print("🏠🏠🏠 ContentView: onAppear called")
            print("🏠 ContentView: onAppear - isLoading = \(authService.isLoading)")
            print("🏠 ContentView: onAppear - isAuthenticated = \(authService.isAuthenticated)")
            // Request location permission on app launch
            locationManager.requestLocationPermission()
        }
        .onChange(of: authService.isLoading) { isLoading in
            print("🏠🏠🏠 ContentView: Loading state changed to \(isLoading)")
            print("🏠 ContentView: Current isLoading = \(authService.isLoading)")
            print("🏠 ContentView: Current isAuthenticated = \(authService.isAuthenticated)")
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            print("🏠🏠🏠 ContentView: Auth state changed to \(isAuthenticated)")
            print("🏠 ContentView: Current isLoading = \(authService.isLoading)")
            print("🏠 ContentView: Current isAuthenticated = \(authService.isAuthenticated)")
        }
    }
}

struct LoadingView: View {
    // Theme color matching #f0c67b (same as launch screen)
    private let backgroundColor = Color(red: 240/255, green: 198/255, blue: 123/255)
    
    init() {
        print("⏳⏳⏳ LoadingView: init() called")
    }
    
    var body: some View {
        ZStack {
            // Same background as launch screen
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Icon - exactly matching launch screen style
                Image(systemName: "fork.knife")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                // App Name - exactly matching launch screen style
                Text("MeshiSele")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // No loading spinner - to match launch screen exactly
            }
        }
        .onAppear {
            print("⏳⏳⏳ LoadingView: onAppear called")
            print("⏳⏳⏳ LoadingView: body getter called")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 