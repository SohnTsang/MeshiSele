import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingDefaultSettings = false
    @State private var showingResetConfirmation = false
    
    // Theme colors matching the app
    private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
    private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)
    
    var body: some View {
        NavigationView {
            Form {
                // Profile Section
                Section {
                    accountSection
                } header: {
                    sectionHeader(title: "プロフィール", icon: "person.circle.fill", color: themeOrange)
                }
                
                // App Settings Section
                Section {
                    appSettingsSection
                } header: {
                    sectionHeader(title: "アプリ設定", icon: "gearshape.fill", color: themeTeal)
                }
                
                // Support Section
                Section {
                    supportSection
                } header: {
                    sectionHeader(title: "サポート", icon: "questionmark.circle.fill", color: themeOrange)
                }
                
                // App Version Footer
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .font(.title2)
                                .foregroundColor(themeOrange)
                                .opacity(0.7)
                            
                            Text(NSLocalizedString("app_name", comment: "App name"))
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("バージョン 1.0")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDefaultSettings) {
                DefaultSettingsView(viewModel: viewModel)
            }
            .alert("サインアウト", isPresented: $viewModel.showSignOutAlert) {
                Button("キャンセル", role: .cancel) {
                    viewModel.cancelSignOut()
                }
                Button("サインアウト", role: .destructive) {
                    viewModel.confirmSignOut()
                }
            } message: {
                Text("本当にサインアウトしますか？")
            }
            .alert("デフォルト設定をリセット", isPresented: $showingResetConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("リセット", role: .destructive) {
                    viewModel.resetDefaultSettings()
                }
            } message: {
                Text("すべてのデフォルト設定を初期値に戻します。この操作は取り消せません。")
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .onAppear {
            // ViewModel initialization is handled in init()
        }
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 20, height: 20)
            
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }
    
    private var budgetSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "yensign.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                
                Text("予算設定 (カスタム初期値)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最低金額")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("500", text: .constant(UserDefaults.standard.string(forKey: "defaultMinBudget") ?? "500"))
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                // Handle min budget change
                            }
                        
                        Text("円")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(spacing: 20) {
                    Text("〜")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("最高金額")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("1000", text: .constant(UserDefaults.standard.string(forKey: "defaultMaxBudget") ?? "1000"))
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                // Handle max budget change
                            }
                        
                        Text("円")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("ホーム画面でカスタム予算を選択した時の初期値です")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var accountSection: some View {
        Group {
            // Display Name with enhanced styling
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle")
                    .font(.title3)
                    .foregroundColor(themeOrange)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ユーザー名")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if viewModel.isEditingDisplayName {
                        HStack(spacing: 8) {
                            TextField("ユーザー名を入力", text: $viewModel.tempDisplayName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 14))
                            
                            Button("保存") {
                                viewModel.saveDisplayName()
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeOrange)
                            .clipShape(Capsule())
                            .disabled(viewModel.tempDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            Button("キャンセル") {
                                viewModel.cancelEditingDisplayName()
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        }
                    } else {
                        Button(action: {
                            viewModel.startEditingDisplayName()
                        }) {
                            HStack(spacing: 6) {
                                Text(viewModel.displayName.isEmpty ? "未設定" : viewModel.displayName)
                                    .font(.system(size: 14))
                                    .foregroundColor(viewModel.displayName.isEmpty ? .secondary : .primary)
                                
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(themeTeal)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Email with enhanced styling
            HStack(spacing: 12) {
                Image(systemName: "envelope.circle")
                    .font(.title3)
                    .foregroundColor(themeTeal)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("メールアドレス")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(viewModel.email)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Sign Out Button with enhanced styling
            Button(action: {
                viewModel.requestSignOut()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .medium))
                    
                    Text("サインアウト")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.vertical, 4)
        }
    }
    
    private var appSettingsSection: some View {
        Group {
            // Dark Mode Settings with enhanced styling using original toggle
            HStack(spacing: 12) {
                Image(systemName: "moon.circle")
                    .font(.title3)
                    .foregroundColor(themeTeal)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ダークモード")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(viewModel.darkModeEnabled ? "ダークモード有効" : "ライトモード有効")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.darkModeEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: themeOrange))
                    .onChange(of: viewModel.darkModeEnabled) { newValue in
                        viewModel.updateDarkModePreference(enabled: newValue)
                    }
            }
            .padding(.vertical, 4)
            
            // Default Meal Settings with enhanced styling
            Button(action: {
                showingDefaultSettings = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.title3)
                        .foregroundColor(themeOrange)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("デフォルト食事設定")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("お好みの初期設定をカスタマイズ")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            
            // Reset Default Settings with enhanced styling
            Button(action: {
                showingResetConfirmation = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.title3)
                        .foregroundColor(.orange)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("デフォルト設定をリセット")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("すべての設定を初期状態に戻す")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .opacity(viewModel.isLoading ? 0.6 : 1.0)
            }
            .disabled(viewModel.isLoading)
            .padding(.vertical, 4)
        }
    }
    
    private var supportSection: some View {
        Group {
            // Privacy Policy with enhanced styling
            Button(action: {
                viewModel.openPrivacyPolicy()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.circle")
                        .font(.title3)
                        .foregroundColor(themeTeal)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("プライバシーポリシー")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("個人情報の取り扱いについて")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
            
            // Terms of Service with enhanced styling
            Button(action: {
                viewModel.openTermsOfService()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                        .foregroundColor(themeOrange)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("利用規約")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("サービス利用規約について")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
            
            // Contact Support with enhanced styling
            Button(action: {
                viewModel.contactSupport()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "message.circle")
                        .font(.title3)
                        .foregroundColor(themeTeal)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("お問い合わせ")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("ご質問やご要望はこちら")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "envelope")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

struct DefaultSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Theme colors
    private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
    private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)
    
    @State private var selectedTab: MealMode = .cook
    
    // Cook mode defaults
    @State private var cookDietFilter: DietFilter = .all
    @State private var cookCuisine: CuisineOption? = nil
    @State private var cookIsSurprise: Bool = false
    @State private var cookSpecifiedIngredients: [String] = []
    @State private var cookExcludedIngredients: [String] = []
    @State private var cookExcludedAllergens: [String] = []
    @State private var cookServingsCount: Int = 2
    @State private var cookBudgetRange: BudgetOption = .noLimit
    @State private var cookCookTimeConstraint: CookTimeOption = .noLimit
    
    // Eat out mode defaults
    @State private var eatOutDietFilter: DietFilter = .all
    @State private var eatOutCuisine: CuisineOption? = nil
    @State private var eatOutIsSurprise: Bool = false
    @State private var eatOutSpecifiedIngredients: [String] = []
    @State private var eatOutExcludedIngredients: [String] = []
    @State private var eatOutExcludedAllergens: [String] = []
    @State private var eatOutBudgetRange: BudgetOption = .noLimit
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Mode", selection: $selectedTab) {
                    Text("料理する").tag(MealMode.cook)
                    Text("外食").tag(MealMode.eatOut)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Form {
                    descriptionSection
                    surpriseModeSection
                    
                    if currentIsSurprise {
                        simplifiedSettingsSections
                    } else {
                        detailedSettingsSections
                    }
                }
            }
            .navigationTitle("デフォルト設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveDefaultSettings()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadCurrentDefaults()
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentIsSurprise: Bool {
        selectedTab == .cook ? cookIsSurprise : eatOutIsSurprise
    }
    
    private var currentDietFilter: Binding<DietFilter> {
        selectedTab == .cook ? $cookDietFilter : $eatOutDietFilter
    }
    
    private var currentCuisine: Binding<CuisineOption?> {
        selectedTab == .cook ? $cookCuisine : $eatOutCuisine
    }
    
    private var currentSpecifiedIngredients: Binding<[String]> {
        selectedTab == .cook ? $cookSpecifiedIngredients : $eatOutSpecifiedIngredients
    }
    
    private var currentExcludedIngredients: Binding<[String]> {
        selectedTab == .cook ? $cookExcludedIngredients : $eatOutExcludedIngredients
    }
    
    private var currentExcludedAllergens: Binding<[String]> {
        selectedTab == .cook ? $cookExcludedAllergens : $eatOutExcludedAllergens
    }
    
    private var currentBudgetRange: Binding<BudgetOption> {
        selectedTab == .cook ? $cookBudgetRange : $eatOutBudgetRange
    }
    
    private var currentIsSurpriseBinding: Binding<Bool> {
        selectedTab == .cook ? $cookIsSurprise : $eatOutIsSurprise
    }
    
    // MARK: - View Components
    
    private var descriptionSection: some View {
        Section {
            Text("設定を変更してホーム画面の初期値をカスタマイズできます")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
        }
    }
    
    private var surpriseModeSection: some View {
        Section("おまかせ／こだわり") {
            Toggle("おまかせで決定", isOn: currentIsSurpriseBinding)
        }
    }
    
    @ViewBuilder
    private var detailedSettingsSections: some View {
        cuisineSection
        dietTypeSection
        ingredientSection
        excludedIngredientsSection
        excludedAllergensSection
        
        if selectedTab == .cook {
            servingsSection
        }
        
        budgetSection
        
        if selectedTab == .cook {
            cookingTimeSection
        }
    }
    
    @ViewBuilder
    private var simplifiedSettingsSections: some View {
        cuisineSection
        dietTypeSection
        budgetSection
    }
    
    private var dietTypeSection: some View {
        Section("ダイエットタイプを選択") {
            Picker("ダイエットタイプ", selection: currentDietFilter) {
                ForEach(DietFilter.allCases, id: \.self) { diet in
                    Text(diet.displayName).tag(diet)
                }
            }
        }
    }
    
    private var cuisineSection: some View {
        Section("料理ジャンルを選択") {
            Picker("料理ジャンル", selection: currentCuisine) {
                Text("すべて").tag(CuisineOption.all as CuisineOption?)
                ForEach(CuisineOption.allCases.filter { $0 != .all }, id: \.self) { cuisine in
                    Text(cuisine.displayName).tag(cuisine as CuisineOption?)
                }
            }
        }
    }
    
    private var ingredientSection: some View {
        Section("食材を入力") {
            VStack(alignment: .leading, spacing: 12) {
                Text("デフォルトで使用する食材を設定してください")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                IngredientInputView(selectedIngredients: currentSpecifiedIngredients)
                
                Text("注: この設定は目安です。ホーム画面で自由に変更できます。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var excludedIngredientsSection: some View {
        Section("除外する食材") {
            Text("除外したい食材を選択してください")
                .font(.caption)
                .foregroundColor(.secondary)
            
            IngredientChips(selectedIngredients: currentExcludedIngredients)
        }
    }
    
    private var excludedAllergensSection: some View {
        Section("除外するアレルゲン") {
            Text("アレルギーがある方は該当するアレルゲンを選択してください")
                .font(.caption)
                .foregroundColor(.secondary)
            
            AllergenChips(excludedAllergens: currentExcludedAllergens)
        }
    }
    
    private var servingsSection: some View {
        Section("何人分？") {
            Stepper("人数: \(cookServingsCount)人前", value: $cookServingsCount, in: 1...10)
        }
    }
    
    private var budgetSection: some View {
        Section("予算 (1人あたり)") {
            Picker("予算 (1人あたり)", selection: currentBudgetRange) {
                ForEach(BudgetOption.presetCases, id: \.rawValue) { budget in
                    Text(budget.displayName).tag(budget)
                }
            }
        }
    }
    
    private var cookingTimeSection: some View {
        Section("調理時間を選択") {
            Picker("調理時間", selection: $cookCookTimeConstraint) {
                ForEach(CookTimeOption.allCases, id: \.self) { time in
                    Text(time.displayName).tag(time)
                }
            }
        }
    }
    

    
    private func loadCurrentDefaults() {
        guard let user = viewModel.user else { return }
        let prefs = user.defaultPreferences
        
        // Load cook mode settings
        if let dietFilterString = prefs.cookDietFilter,
           let dietFilter = DietFilter(rawValue: dietFilterString) {
            cookDietFilter = dietFilter
        } else {
            // Default to "all" if no preference is saved
            cookDietFilter = .all
        }
        
        if let cuisineString = prefs.cookCuisine,
           let cuisine = CuisineOption(rawValue: cuisineString) {
            cookCuisine = cuisine
        } else {
            // Default to "all" if no preference is saved
            cookCuisine = .all
        }
        
        cookIsSurprise = prefs.cookIsSurprise
        cookSpecifiedIngredients = prefs.cookSpecifiedIngredients
        cookExcludedIngredients = prefs.cookExcludedIngredients
        cookExcludedAllergens = prefs.cookExcludedAllergens
        cookServingsCount = prefs.cookServingsCount
        
        if let budget = BudgetOption(rawValue: prefs.cookBudgetRange) {
            cookBudgetRange = budget
        }
        
        if let time = CookTimeOption(rawValue: prefs.cookCookTimeConstraint) {
            cookCookTimeConstraint = time
        }
        
        // Load eat out mode settings
        if let dietFilterString = prefs.eatOutDietFilter,
           let dietFilter = DietFilter(rawValue: dietFilterString) {
            eatOutDietFilter = dietFilter
        } else {
            // Default to "all" if no preference is saved
            eatOutDietFilter = .all
        }
        
        if let cuisineString = prefs.eatOutCuisine,
           let cuisine = CuisineOption(rawValue: cuisineString) {
            eatOutCuisine = cuisine
        } else {
            // Default to "all" if no preference is saved
            eatOutCuisine = .all
        }
        
        eatOutIsSurprise = prefs.eatOutIsSurprise
        eatOutSpecifiedIngredients = prefs.eatOutSpecifiedIngredients
        eatOutExcludedIngredients = prefs.eatOutExcludedIngredients
        eatOutExcludedAllergens = prefs.eatOutExcludedAllergens
        
        if let budget = BudgetOption(rawValue: prefs.eatOutBudgetRange) {
            eatOutBudgetRange = budget
        }
    }
    
    private func saveDefaultSettings() {
        guard var user = viewModel.user else { return }
        
        user.defaultPreferences = User.DefaultPreferences(
            // Cook mode settings
            cookDietFilter: cookDietFilter.rawValue,
            cookCuisine: cookCuisine?.rawValue,
            cookIsSurprise: cookIsSurprise,
            cookSpecifiedIngredients: cookSpecifiedIngredients,
            cookExcludedIngredients: cookExcludedIngredients,
            cookExcludedAllergens: cookExcludedAllergens,
            cookServingsCount: cookServingsCount,
            cookBudgetRange: cookBudgetRange.rawValue,
            cookCookTimeConstraint: cookCookTimeConstraint.rawValue,
            
            // Eat out mode settings
            eatOutDietFilter: eatOutDietFilter.rawValue,
            eatOutCuisine: eatOutCuisine?.rawValue,
            eatOutIsSurprise: eatOutIsSurprise,
            eatOutSpecifiedIngredients: eatOutSpecifiedIngredients,
            eatOutExcludedIngredients: eatOutExcludedIngredients,
            eatOutExcludedAllergens: eatOutExcludedAllergens,
            eatOutBudgetRange: eatOutBudgetRange.rawValue
        )
        
        FirebaseService.shared.updateUser(user) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to save default settings: \(error.localizedDescription)")
                } else {
                    AuthService.shared.currentUser = user
                    // Notify HomeView to reload default preferences
                    NotificationCenter.default.post(name: NSNotification.Name("DefaultSettingsUpdated"), object: nil)
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 