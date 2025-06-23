import SwiftUI

// Theme Colors
private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var adService = AdService.shared
    @State private var showingResult = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Playful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.05),
                        Color.pink.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Playful header section
                            playfulHeaderSection
                            .id("header")
                            
                            // Filter Cards
                            playfulFilterCards
                            .id("filters")
                            
                            // Decision Button
                            playfulDecisionButtonSection
                                .id("decisionButton")
                            
                            // Spinner
                            if viewModel.isSpinning && !viewModel.showFullScreenSpinner {
                                playfulSpinnerSection
                                .id("spinner")
                            }
                            
                            // Validation Errors
                            if !viewModel.validationErrors.isEmpty {
                                validationErrorsSection
                                .id("errors")
                            }
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: viewModel.isSurprise) { isSurprise in
                        if isSurprise == true {
                            // Auto scroll to decision button when random is selected
                            withAnimation(.easeInOut(duration: 0.8)) {
                                proxy.scrollTo("decisionButton", anchor: .center)
                            }
                        }
                    }
                }
                
                // Full Screen Spinner Overlay
                if viewModel.showFullScreenSpinner {
                    fullScreenSpinnerOverlay
                }
                
                // Full Screen Error Overlay
                if viewModel.showFullScreenError {
                    fullScreenErrorOverlay
                }
                
                // Result Overlay
                if let result = viewModel.spinnerResult {
                    resultOverlay(result: result)
                        .onAppear {
                            // Ensure loading state is reset when result overlay appears
                            viewModel.setIsLoading(false)
                        }
                }
                
                // Congratulations Overlay
                if viewModel.showCongratulationsOverlay {
                    congratulationsOverlay
                }
                
                // Restaurant Search Overlay (only for 外食 mode)
                if viewModel.isSearchingRestaurants {
                    restaurantSearchOverlay
                }
                
                // Google AdMob handles interstitial ads natively, no overlay needed
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .font(.title3)
                            .foregroundColor(themeOrange)
                        
                        Text(NSLocalizedString("app_name", comment: "App name"))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingResult) {
                if let result = viewModel.latestResult {
                    resultDetailSheet(result: result)
                }
            }
            .sheet(isPresented: $viewModel.showingRestaurantList) {
                NavigationView {
                    RestaurantListView(restaurants: viewModel.restaurantList)
                }
            }
        }
        .onAppear {
            // Only set diet filter if it's actually nil, don't force refresh
            if viewModel.selectedDietFilter == nil {
                viewModel.selectedDietFilter = .all
            }
        }
    }
    
    // MARK: - Playful Header Section
    private var playfulHeaderSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("今日のごはん、")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("どうしよう？")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Fun subtitle with app name
                HStack(spacing: 4) {
                    Text(NSLocalizedString("app_name", comment: "App name"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(themeOrange)
                    
                    Text(NSLocalizedString("decide_quickly", comment: "Decide quickly"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(themeTeal)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .padding(.bottom, 10)
    }
    
    private var playfulFilterCards: some View {
        VStack(spacing: 16) {
            // 1. Meal Mode Selection (always enabled)
            PlayfulMealModeFilterCard(selectedMode: $viewModel.selectedMealMode)
                .padding(.horizontal)
            
            // 2. Ingredient Mode Selection (always enabled)
            PlayfulIngredientModeFilterCard(
                isSurprise: $viewModel.isSurprise,
                onSurpriseModeChanged: viewModel.onSurpriseModeManuallyChanged
            )
            .padding(.horizontal)
            
            // Only show additional sections if a meal mode is selected
            if viewModel.selectedMealMode != nil {
                // First Banner Ad - After every 2 sections (sections 1 & 2 completed)
                HomeBannerAdView(id: "banner1")
                    .padding(.horizontal)
                    .id("banner1")
                
                if viewModel.isSurprise != true {
                    // こだわり mode - Only show these filters when not in surprise mode
                    // 3. Cuisine Selection
                    PlayfulCuisineFilterCard(selectedCuisine: $viewModel.selectedCuisine)
                        .padding(.horizontal)
                    
                    // 4. Diet Type Selection
                    PlayfulDietFilterCard(selectedDiet: $viewModel.selectedDietFilter)
                        .padding(.horizontal)
                    
                    // Second Banner Ad - After sections 3 & 4
                    HomeBannerAdView(id: "banner2")
                        .padding(.horizontal)
                        .id("banner2")
                    
                    // 5. Ingredient Selection
                    PlayfulIngredientsFilterCard(
                        ingredients: $viewModel.specifiedIngredients
                    )
                    .padding(.horizontal)
                    
                    // 6. Excluded Ingredients
                    PlayfulExcludedIngredientsFilterCard(excludedIngredients: $viewModel.excludedIngredients)
                        .padding(.horizontal)
                    
                    // Third Banner Ad - After sections 5 & 6
                    HomeBannerAdView(id: "banner3")
                        .padding(.horizontal)
                        .id("banner3")
                    
                    // 7. Excluded Allergens
                    PlayfulExcludedAllergensFilterCard(excludedAllergens: $viewModel.excludedAllergens)
                        .padding(.horizontal)
                    
                    // 8. Budget Selection
                    PlayfulBudgetFilterCard(budgetRange: $viewModel.budgetRange)
                        .padding(.horizontal)
                    
                    // Fourth Banner Ad - After sections 7 & 8
                    HomeBannerAdView(id: "banner4")
                        .padding(.horizontal)
                        .id("banner4")
                    
                    // 9. Cooking Time Selection (only for cooking mode)
                    if viewModel.selectedMealMode == .cook {
                        PlayfulCookingTimeFilterCard(cookTimeConstraint: $viewModel.cookTimeConstraint)
                            .padding(.horizontal)
                    }
                } else {
                    // お任せ mode - Minimal filters for random mode
                    // 3. Cuisine Selection
                    PlayfulCuisineFilterCard(selectedCuisine: $viewModel.selectedCuisine)
                        .padding(.horizontal)
                    
                    // 4. Diet Type Selection (simplified)
                    PlayfulDietFilterCard(selectedDiet: $viewModel.selectedDietFilter)
                        .padding(.horizontal)
                    
                    // 5. Budget Selection for random mode
                    PlayfulBudgetFilterCard(budgetRange: $viewModel.budgetRange)
                        .padding(.horizontal)
                    
                    // Second Banner Ad - After sections 3, 4 & 5 (お任せ mode)
                    HomeBannerAdView(id: "banner2_random")
                        .padding(.horizontal)
                        .id("banner2_random")
                }
            }
        }
    }
    
    private var playfulDecisionButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                if viewModel.isReadyToDecide {
                    // Set loading state immediately
                    viewModel.setIsLoading(true)
                    
                    let shouldShowAd = viewModel.shouldShowAd()
                    
                    // Show interstitial ad first if needed, then make decision
                    if shouldShowAd {
                        Task { @MainActor in
                            await adService.showInterstitialAd {
                                // Execute meal decision after ad is dismissed
                                DispatchQueue.main.async {
                                    viewModel.executeMealDecision()
                                }
                            }
                        }
                    } else {
                        viewModel.executeMealDecision()
                    }
                }
            }) {
                HStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        // Fun wand icon with static rotation
                        Image(systemName: "wand.and.rays")
                            .font(.title2)
                            .rotationEffect(.degrees(viewModel.isReadyToDecide ? 15 : 0))
                            .foregroundColor(.white)
                    }
                    
                    Text("決定！")
                        .fontWeight(.bold)
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Group {
                        if viewModel.isReadyToDecide {
                            LinearGradient(
                                gradient: Gradient(colors: [themeOrange, themeTeal]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                gradient: Gradient(colors: [Color.gray, Color.gray]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .cornerRadius(16)
                .shadow(color: viewModel.isReadyToDecide ? themeOrange.opacity(0.3) : Color.gray.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(!viewModel.isReadyToDecide)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    private var playfulSpinnerSection: some View {
        VStack(spacing: 20) {
            Text("おいしいものを探してます...🔍")
                .font(.headline)
                .foregroundColor(themeOrange)
                .fontWeight(.semibold)
            
            SpinnerView(isSpinning: $viewModel.isSpinning)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: themeOrange.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .padding(.horizontal)
    }
    
    private var validationErrorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(themeOrange)
                Text("以下を確認してください：")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeOrange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.validationErrors, id: \.self) { error in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(themeOrange)
                            .fontWeight(.bold)
                        Text(error)
                            .foregroundColor(.primary)
                            .font(.body)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeOrange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeOrange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
    
    private func resultDetailSheet(result: MealResult) -> some View {
        NavigationView {
            Group {
                if result.type == .recipe, let recipe = result.recipe {
                    RecipeDetailView(recipe: recipe, initialServings: viewModel.servingsCount)
                } else if result.type == .restaurant, let restaurant = result.restaurant {
                    RestaurantDetailView(restaurant: restaurant)
                } else if result.type == .eatingOutMeal, let eatingOutMeal = result.eatingOutMeal {
                    // Simple detail view for eating out meals
                    VStack(spacing: 20) {
                        Text(eatingOutMeal.emoji)
                            .font(.system(size: 100))
                        
                        Text(eatingOutMeal.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(eatingOutMeal.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "yensign.circle")
                                Text("予算: 約¥\(eatingOutMeal.estimatedBudget)")
                            }
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("人気度: \(eatingOutMeal.popularityCount)")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    Text("結果を読み込めませんでした")
                        .foregroundColor(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button(action: {
                    showingResult = false
                }) {
                    Text("完了")
                        .fontWeight(.semibold)
                }
            )
        }
    }
    
    private var congratulationsOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewModel.showCongratulationsOverlay = false
                        }
                    }
                
                // Centered content matching error overlay style
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        // Main message
                        Text("選択を保存しました！")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("おいしいお食事をお楽しみください✨")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        // Recipe confirmation button (primary)
                        Button(action: {
                            if viewModel.latestResult != nil {
                                showingResult = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("レシピを確認")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(
                                        gradient: Gradient(colors: [themeOrange, themeOrange.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .shadow(color: themeOrange.opacity(0.4), radius: 8, x: 0, y: 4)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Close button (secondary)
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                viewModel.showCongratulationsOverlay = false
                            }
                        }) {
                            Text("閉じる")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 24)
                }
                .padding(36)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(LinearGradient(
                                    gradient: Gradient(colors: [themeOrange.opacity(0.3), themeOrange.opacity(0.1)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), lineWidth: 1.5)
                        )
                )
                .frame(maxWidth: min(500, geometry.size.width * 0.9))
                .scaleEffect(viewModel.showCongratulationsOverlay ? 1.0 : 0.8)
                .opacity(viewModel.showCongratulationsOverlay ? 1.0 : 0.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showCongratulationsOverlay)
                .frame(maxWidth: .infinity, maxHeight: .infinity) // This centers the content
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showCongratulationsOverlay)
    }
    
    private var fullScreenSpinnerOverlay: some View {
        ZStack {
            // Grey overlay background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Fancy colorful spinner with multiple layers
                ZStack {
                    // Outer rotating ring with gradient
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.blue, .purple, .pink, .orange, .yellow, .green, .blue]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(viewModel.spinnerRotation))
                    
                    // Middle ring with different rotation speed
                    Circle()
                        .trim(from: 0.2, to: 0.9)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.cyan, .blue, .purple, .pink]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-viewModel.spinnerRotation * 1.5))
                    
                    // Simplified inner dots
                        Circle()
                        .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .offset(y: -25)
                        .rotationEffect(.degrees(viewModel.spinnerRotation * 2))
                    
                    // Center icon
                    Image(systemName: "wand.and.rays")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .blue, radius: 4)
                }
                
                // Animated text with gradient
                VStack(spacing: 8) {
                    Text("おいしいものを探してます")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                                            HStack(spacing: 4) {
                        Text("🍜").font(.title3)
                        Text("🍱").font(.title3)
                        Text("🍲").font(.title3)
                        Text("🍤").font(.title3)
                        Text("🍛").font(.title3)
                        }
                    }
                }
            }
            .padding(40)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showFullScreenSpinner)
    }
    
    private var fullScreenErrorOverlay: some View {
        ZStack {
            // Dark overlay background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Error icon with enhanced orange theme
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [themeOrange, themeOrange.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 90, height: 90)
                        .shadow(color: themeOrange.opacity(0.4), radius: 12, x: 0, y: 6)
                    
                    if viewModel.errorMessage?.contains("該当するレシピが見つかりませんでした") == true {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(spacing: 16) {
                    // Enhanced error message styling
                    Text(viewModel.errorMessage ?? "エラーが発生しました")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    
                    if viewModel.errorMessage?.contains("該当するレシピが見つかりませんでした") == true {
                        VStack(spacing: 8) {
                            Text("🍽️ 条件に合うレシピが見つかりませんでした")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("• 予算範囲を広げてみてください\n• 除外食材を減らしてみてください\n• 料理の種類を変更してみてください")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 8)
                    }
                }
                
                Button(action: {
                    viewModel.clearError()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("もう一度試す")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [themeOrange, themeOrange.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .shadow(color: themeOrange.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(LinearGradient(
                                gradient: Gradient(colors: [themeOrange.opacity(0.3), themeOrange.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1.5)
                    )
            )
            .padding(.horizontal, 32)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showFullScreenError)
    }
    
    private func resultOverlay(result: MealResult) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Black background overlay
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Allow dismissing by tapping background (optional)
                    }
                
                ScrollView {
                    ResultContentView(
                        result: result,
                        geometry: geometry,
                        viewModel: viewModel,
                        adService: adService,
                        showingResult: $showingResult
                    )
                    .padding(min(32, geometry.size.width * 0.08))
                    .frame(maxWidth: min(550, geometry.size.width * 0.98))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.spinnerResult != nil)
    }
    
    private var restaurantSearchOverlay: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Search icon with animation
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [themeOrange, themeTeal]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 12) {
                    Text("お店を探しています...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("近くの美味しいお店を\n見つけています")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                // Loading indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeOrange))
                    .scaleEffect(1.2)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        ))
    }
}

// MARK: - Playful Filter Cards

struct PlayfulMealModeFilterCard: View {
    @Binding var selectedMode: MealMode?
    
    private let selectedBackgroundGradient = LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    
    private let normalBackgroundGradient = LinearGradient(
            gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    
    private func modeButton(for mode: MealMode) -> some View {
        Button(action: {
            selectedMode = mode
        }) {
            VStack(spacing: 8) {
                Image(systemName: mode == .cook ? "house.fill" : "building.2.fill")
                    .font(.title2)
                Text(mode.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                selectedMode == mode ? selectedBackgroundGradient : normalBackgroundGradient
            )
            .cornerRadius(12)
            .scaleEffect(selectedMode == mode ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: selectedMode)
        }
        .foregroundColor(selectedMode == mode ? .white : .primary)
    }
    
    var body: some View {
        PlayfulFilterCard(
            title: "料理モードを選択",
            icon: "fork.knife",
            isRequired: true,
            isValid: selectedMode != nil
        ) {
            HStack(spacing: 12) {
                modeButton(for: .cook)
                modeButton(for: .eatOut)
            }
        }
    }
}

struct PlayfulIngredientModeFilterCard: View {
    @Binding var isSurprise: Bool?
    let onSurpriseModeChanged: () -> Void
    
    private let surpriseSelectedGradient = LinearGradient(
            gradient: Gradient(colors: [themeOrange.opacity(0.7), Color.pink.opacity(0.6)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    
    private let specifySelectedGradient = LinearGradient(
            gradient: Gradient(colors: [themeTeal.opacity(0.7), themeTeal.opacity(0.6)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    
    private var normalGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.1)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        PlayfulFilterCard(
            title: "おまかせ／こだわり",
            icon: "heart.text.square.fill",
            emoji: "🎯"
        ) {
            HStack(spacing: 12) {
                Button(action: {
                    isSurprise = true
                    onSurpriseModeChanged()
                }) {
                    VStack(spacing: 8) {
                        Text("🎲")
                            .font(.title)
                        Text("おまかせ")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        (isSurprise == true) ? surpriseSelectedGradient : normalGradient
                    )
                    .cornerRadius(12)
                    .scaleEffect((isSurprise == true) ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: isSurprise)
                }
                .foregroundColor((isSurprise == true) ? .white : .primary)
                
                Button(action: {
                    isSurprise = false
                    onSurpriseModeChanged()
                }) {
                    VStack(spacing: 8) {
                        Text("🎯")
                            .font(.title)
                        Text("こだわり")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        (isSurprise == false) ? specifySelectedGradient : normalGradient
                    )
                    .cornerRadius(12)
                    .scaleEffect((isSurprise == false) ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3), value: isSurprise)
                }
                .foregroundColor((isSurprise == false) ? .white : .primary)
            }
        }
    }
}

struct PlayfulDietFilterCard: View {
    @Binding var selectedDiet: DietFilter?
    @State private var refreshTrigger = false
    @State private var viewHasAppeared = false
    
    @ViewBuilder
    private func backgroundForDiet(_ diet: DietFilter) -> some View {
        let isSelected = selectedDiet == diet
        RoundedRectangle(cornerRadius: 12)
            .fill(isSelected ? themeOrange.opacity(0.2) : Color(.systemGray6))
            .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? themeOrange : Color.clear, lineWidth: 2)
            )
            .id("diet-bg-\(diet.rawValue)-\(refreshTrigger)")
    }
    
    private func dietButton(for diet: DietFilter) -> some View {
        let isSelected = selectedDiet == diet
        return Button(action: {
            selectedDiet = selectedDiet == diet ? nil : diet
            refreshTrigger.toggle()
        }) {
            VStack(spacing: 6) {
                Text(diet.emoji)
                    .font(.title2)
                Text(diet.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(backgroundForDiet(diet))
            .foregroundColor(isSelected ? themeOrange : .primary)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: selectedDiet)
        }
        .id("diet-btn-\(diet.rawValue)-\(refreshTrigger)")
    }
    
    var body: some View {
        PlayfulFilterCard(
            title: "ダイエットタイプを選択",
            icon: "leaf.fill",
            emoji: "🥗"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                dietButton(for: .all)
                dietButton(for: .healthy)
                                            dietButton(for: .vegetarian)
                dietButton(for: .lowCarb)
                dietButton(for: .glutenFree)
                dietButton(for: .meat)
            }
            .id("diet-filter-grid")
        }
        .onAppear {
            viewHasAppeared = true
            // Force UI refresh with the current value to ensure it's properly displayed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                refreshTrigger.toggle()
                // If no diet is selected but we should have a default, set it
                if selectedDiet == nil {
                    selectedDiet = .all
                }
            }
        }
        .onChange(of: selectedDiet) { newValue in
            // Trigger refresh when diet changes
            if viewHasAppeared {
                DispatchQueue.main.async {
                    refreshTrigger.toggle()
                }
            }
        }
    }
}

struct PlayfulCuisineFilterCard: View {
    @Binding var selectedCuisine: CuisineOption?
    
    @ViewBuilder
    private func backgroundForCuisine(_ cuisine: CuisineOption) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(selectedCuisine == cuisine ? themeOrange.opacity(0.2) : Color(.systemGray6))
            .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(selectedCuisine == cuisine ? themeOrange : Color.clear, lineWidth: 2)
            )
    }
    
    private func cuisineButton(for cuisine: CuisineOption) -> some View {
        Button(action: {
            selectedCuisine = selectedCuisine == cuisine ? nil : cuisine
        }) {
            VStack(spacing: 6) {
                Text(cuisine.emoji)
                    .font(.title2)
                Text(cuisine.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(width: 80, height: 80)
            .background(backgroundForCuisine(cuisine))
            .foregroundColor(selectedCuisine == cuisine ? themeOrange : .primary)
            .scaleEffect(selectedCuisine == cuisine ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: selectedCuisine)
        }
    }
    
    var body: some View {
        PlayfulFilterCard(
            title: NSLocalizedString("select_cuisine", comment: "Select cuisine"),
            icon: "globe.asia.australia.fill",
            emoji: "🌍"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    cuisineButton(for: .all)
                cuisineButton(for: .washoku)
                cuisineButton(for: .yoshoku)
                cuisineButton(for: .chuka)
                cuisineButton(for: .italian)
                    cuisineButton(for: .korean)
                    cuisineButton(for: .french)
                cuisineButton(for: .other)
            }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .frame(height: 100)
            .id("cuisine-filter-scroll")
        }
    }
}

struct PlayfulIngredientsFilterCard: View {
    @Binding var ingredients: [String]
    
    private func addCommonIngredient(_ ingredient: CommonIngredient) {
        let ingredientName = ingredient.displayName
        if !ingredients.contains(ingredientName) {
            // Use a temporary binding to add the ingredient
            var tempIngredients = ingredients
            tempIngredients.append(ingredientName)
            ingredients = tempIngredients
        }
    }
    
    var body: some View {
        PlayfulFilterCard(
            title: "食材を入力",
            icon: "carrot.fill",
            emoji: "🥕"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                // Enhanced input with autocomplete
                IngredientInputView(selectedIngredients: $ingredients)
                
                // Common ingredients section
                VStack(alignment: .leading, spacing: 8) {
                    Text("よく使う食材")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    // Grouped common ingredients
                    VStack(alignment: .leading, spacing: 12) {
                        // Meats (3)
                        commonIngredientGroup(
                            title: "お肉",
                            ingredients: [.chicken, .pork, .beef]
                        )
                        
                        // Fish & Eggs (3)
                        commonIngredientGroup(
                            title: "魚・卵",
                            ingredients: [.shrimp, .salmon, .egg]
                        )
                        
                        // Vegetables (3)
                        commonIngredientGroup(
                            title: "野菜",
                            ingredients: [.onion, .cabbage, .carrot]
                        )
                        
                        // Main/Staples (3)
                        commonIngredientGroup(
                            title: "主食・その他",
                            ingredients: [.rice, .tofu, .potato]
                        )
                    }
                }
            }
        }
    }
    
    private func commonIngredientGroup(title: String, ingredients: [CommonIngredient]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(ingredients, id: \.self) { ingredient in
                    commonIngredientButton(ingredient)
                }
            }
            .id("common-ingredients-\(title.replacingOccurrences(of: " ", with: "-"))")
        }
    }
    
    private func commonIngredientButton(_ ingredient: CommonIngredient) -> some View {
        let isSelected = ingredients.contains(ingredient.displayName)
        
        return Button(action: {
            addCommonIngredient(ingredient)
        }) {
            HStack(spacing: 4) {
                Text(ingredient.emoji)
                    .font(.caption)
                Text(ingredient.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? themeOrange.opacity(0.2) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? themeOrange : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? themeOrange : .primary)
            .scaleEffect(isSelected ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .disabled(isSelected)
    }
}

struct PlayfulExcludedIngredientsFilterCard: View {
    @Binding var excludedIngredients: [String]
    
    var body: some View {
        PlayfulFilterCard(
            title: "除外する食材",
            icon: "xmark.circle.fill",
            emoji: "🚫"
        ) {
            IngredientChips(selectedIngredients: $excludedIngredients)
        }
    }
}

struct PlayfulExcludedAllergensFilterCard: View {
    @Binding var excludedAllergens: [String]
    
    var body: some View {
        PlayfulFilterCard(
            title: "アレルギー対応",
            icon: "exclamationmark.triangle.fill",
            emoji: "⚠️"
        ) {
            AllergenChips(excludedAllergens: $excludedAllergens)
        }
    }
}

struct PlayfulServingsFilterCard: View {
    @Binding var servingsCount: Int
    
    private let servingOptions = [
        (1, "1人前", "👤"),
        (2, "2人前", "👥"),
        (4, "3〜4人前", "👨‍👩‍👧"),
        (6, "5人前以上", "👨‍👩‍👧‍👦")
    ]
    
    private func backgroundForServing(_ option: (Int, String, String)) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(servingsCount == option.0 ? themeOrange.opacity(0.2) : Color(.systemGray6))
    }
    
    private func strokeForServing(_ option: (Int, String, String)) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(servingsCount == option.0 ? themeOrange : Color.clear, lineWidth: 2)
    }
    
    private func servingButton(for option: (Int, String, String)) -> some View {
        Button(action: {
            servingsCount = option.0
        }) {
            VStack(spacing: 6) {
                Text(option.2)
                    .font(.title2)
                Text(option.1)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                backgroundForServing(option)
                    .overlay(strokeForServing(option))
            )
            .foregroundColor(servingsCount == option.0 ? themeOrange : .primary)
            .scaleEffect(servingsCount == option.0 ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: servingsCount)
        }
    }
    
    var body: some View {
        PlayfulFilterCard(
            title: "何人分？",
            icon: "person.2.fill",
            emoji: "👥"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                servingButton(for: servingOptions[0])
                servingButton(for: servingOptions[1])
                servingButton(for: servingOptions[2])
                servingButton(for: servingOptions[3])
            }
            .id("servings-filter-grid")
        }
    }
}

struct PlayfulBudgetFilterCard: View {
    @Binding var budgetRange: BudgetOption
    @State private var customMinBudget: String = ""
    @State private var customMaxBudget: String = ""
    @State private var isCustomMode: Bool = false
    
    var body: some View {
        PlayfulFilterCard(
            title: "予算(1人あたり)",
            icon: "yensign.circle.fill",
            emoji: "💰"
        ) {
            VStack(spacing: 16) {
                // Toggle between preset and custom
                HStack {
                    Button(action: {
                        isCustomMode = false
                    }) {
                        Text("プリセット")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isCustomMode ? .secondary : themeOrange)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isCustomMode ? Color(.systemGray6) : themeOrange.opacity(0.1))
                            )
                    }
                    
                    Button(action: {
                        isCustomMode = true
                        loadCustomValues()
                    }) {
                        Text("カスタム")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isCustomMode ? themeOrange : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isCustomMode ? themeOrange.opacity(0.1) : Color(.systemGray6))
                            )
                    }
                    
                    Spacer()
                }
                
                if isCustomMode {
                    // Custom budget input
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最低金額")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("500", text: $customMinBudget)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customMinBudget) { _ in
                                    updateBudgetRange()
                                }
                        }
                        
                        Text("から")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 16)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最高金額")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("1000", text: $customMaxBudget)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: customMaxBudget) { _ in
                                    updateBudgetRange()
                                }
                        }
                    }
                    
                    Text("設定で初期値を変更できます")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    // Preset budget options
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(BudgetOption.presetCases, id: \.rawValue) { budget in
                            budgetButton(for: budget)
                        }
                    }
                    .id("budget-filter-grid")
                }
            }
        }
        .onAppear {
            // Only load default values if we don't have current custom values
            if customMinBudget.isEmpty && customMaxBudget.isEmpty {
                loadCustomValues()
            }
            
            // If the current budget is custom, populate the text fields with current values
            if case .custom(let min, let max) = budgetRange {
                customMinBudget = String(min)
                customMaxBudget = String(max)
                isCustomMode = true
            }
        }
    }
    
    private func backgroundForBudget(_ budget: BudgetOption) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(budgetRange == budget ? themeOrange.opacity(0.2) : Color(.systemGray6))
    }
    
    private func strokeForBudget(_ budget: BudgetOption) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(budgetRange == budget ? themeOrange : Color.clear, lineWidth: 2)
    }
    
    private func budgetButton(for budget: BudgetOption) -> some View {
        Button(action: {
            budgetRange = budget
        }) {
            VStack(spacing: 6) {
                Text(budget.emoji)
                    .font(.title2)
                Text(budget.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                backgroundForBudget(budget)
                    .overlay(strokeForBudget(budget))
            )
            .foregroundColor(budgetRange == budget ? themeOrange : .primary)
            .scaleEffect(budgetRange == budget ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: budgetRange)
        }
    }
    
    private func loadCustomValues() {
        // Load default values from UserDefaults or settings
        customMinBudget = UserDefaults.standard.string(forKey: "defaultMinBudget") ?? "500"
        customMaxBudget = UserDefaults.standard.string(forKey: "defaultMaxBudget") ?? "1000"
    }
    
    private func updateBudgetRange() {
        // Update budget range based on custom input
        let min = Int(customMinBudget) ?? 500
        let max = Int(customMaxBudget) ?? 1000
        
        // Validate input
        guard min > 0 && max > 0 && min <= max else {
            // If invalid input, fall back to a reasonable default
            budgetRange = .between500_1000
            return
        }
        
        // Create custom budget option
        budgetRange = .custom(min: min, max: max)
    }
}

struct PlayfulCookingTimeFilterCard: View {
    @Binding var cookTimeConstraint: CookTimeOption
    
    private func backgroundForTime(_ time: CookTimeOption) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(cookTimeConstraint == time ? themeTeal.opacity(0.2) : Color(.systemGray6))
    }
    
    private func strokeForTime(_ time: CookTimeOption) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(cookTimeConstraint == time ? themeTeal : Color.clear, lineWidth: 2)
    }
    
    private func timeButton(for time: CookTimeOption) -> some View {
        Button(action: {
            cookTimeConstraint = time
        }) {
            VStack(spacing: 6) {
                Text(time.emoji)
                    .font(.title2)
                Text(time.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                backgroundForTime(time)
                    .overlay(strokeForTime(time))
            )
            .foregroundColor(cookTimeConstraint == time ? themeTeal : .primary)
            .scaleEffect(cookTimeConstraint == time ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: cookTimeConstraint)
        }
    }
    
    var body: some View {
        PlayfulFilterCard(
            title: "調理時間を選択",
            icon: "clock.fill",
            emoji: "⏰"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                timeButton(for: .tenMin)
                timeButton(for: .thirtyMin)
                timeButton(for: .sixtyMin)
                timeButton(for: .noLimit)
            }
            .id("cooking-time-filter-grid")
        }
    }
}

struct PlayfulNotificationFilterCard: View {
    @Binding var notificationsEnabled: Bool
    
    var body: some View {
        PlayfulFilterCard(
            title: "リマインダーを受け取る",
            icon: "bell.fill",
            emoji: "🔔"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $notificationsEnabled) {
                    HStack(spacing: 8) {
                        Text("📱")
                            .font(.title3)
                        Text("お知らせを受け取る")
                            .fontWeight(.medium)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: themeOrange))
                
                Text("設定 > 通知 でも変更可能です。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Playful Filter Card Base

struct PlayfulFilterCard<Content: View>: View {
    let title: String
    let icon: String
    let emoji: String?
    let isRequired: Bool
    let isValid: Bool
    let content: Content
    
    init(
        title: String,
        icon: String,
        emoji: String? = nil,
        isRequired: Bool = false,
        isValid: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.emoji = emoji
        self.isRequired = isRequired
        self.isValid = isValid
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                                         .foregroundColor(themeOrange)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
                
                if let emoji = emoji {
                    Text(emoji)
                        .font(.title3)
                }
                
                Spacer()
                
                if !isValid {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Playful Chip Components

struct PlayfulRemovableChipGroup: View {
    let items: [String]
    let onRemove: (String) -> Void
    
    private var chipBackground: some View {
        Capsule()
            .fill(themeOrange.opacity(0.1))
    }
    
    private var chipStroke: some View {
        Capsule()
            .stroke(themeOrange.opacity(0.3), lineWidth: 1)
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 6) {
                    Text(item)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Button(action: {
                        onRemove(item)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    chipBackground
                        .overlay(chipStroke)
                )
                .foregroundColor(themeOrange)
            }
        }
        .id("removable-chips-\(items.count)")
    }
}

// MARK: - Helper Views

struct ResultContentView: View {
    let result: MealResult
    let geometry: GeometryProxy
    let viewModel: HomeViewModel
    let adService: AdService
    @Binding var showingResult: Bool
    
    private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                // Enhanced result message styling
                Text("見つけました！")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(result.type == .recipe ? "おすすめレシピ" : (result.type == .restaurant ? "おすすめのお店" : "今日はこれはいかがですか？"))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Result card (keep existing design but integrate better)
            ResultCardView(result: result, geometry: geometry)
            
            // Action buttons with orange theme
            VStack(spacing: 12) {
                ResultActionButtonsView(
                    result: result, 
                    geometry: geometry, 
                    viewModel: viewModel, 
                    adService: adService
                )
                
                // View details button (secondary style)
                Button(action: {
                    showingResult = true
                }) {
                    Text(LocalizedString("view_details"))
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
                
                // Cancel button (tertiary style)
                Button(action: {
                    viewModel.clearResult()
                }) {
                    Text(LocalizedString("cancel"))
                        .font(.footnote)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [themeOrange.opacity(0.3), themeOrange.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 1.5)
                )
        )
        .frame(maxWidth: min(550, geometry.size.width * 0.9))
    }
}

struct ResultCardView: View {
    let result: MealResult
    let geometry: GeometryProxy
    
    var body: some View {
        VStack(spacing: 16) {
            // Image or placeholder with responsive sizing
            if result.type == .eatingOutMeal, let eatingOutMeal = result.eatingOutMeal {
                // Special display for eating out meals with emoji
                VStack(spacing: 16) {
                    Text(eatingOutMeal.emoji)
                        .font(.system(size: min(80, geometry.size.width * 0.2)))
                    
                    Text(eatingOutMeal.description)
                        .font(.system(size: min(16, geometry.size.width * 0.04)))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .frame(height: min(180, geometry.size.height * 0.25))
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [themeOrange.opacity(0.15), themeTeal.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if let imageURL = result.displayImage, !imageURL.isEmpty {
                AsyncImageView(
                    imageURL: imageURL,
                    resultType: result.type,
                    frameHeight: min(180, geometry.size.height * 0.25),
                    iconSize: min(40, geometry.size.width * 0.1)
                )
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [themeOrange.opacity(0.3), themeTeal.opacity(0.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: result.type == .recipe ? "fork.knife" : (result.type == .restaurant ? "building.2" : "fork.knife.circle"))
                            .font(.system(size: min(40, geometry.size.width * 0.1)))
                            .foregroundColor(.white)
                    )
                    .frame(height: min(180, geometry.size.height * 0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            
            // Result name
            Text(result.displayName)
                .font(.system(size: min(20, geometry.size.width * 0.05), weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(.horizontal)
        }
        .padding(min(24, geometry.size.width * 0.06))
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
    }
}

struct ResultActionButtonsView: View {
    let result: MealResult
    let geometry: GeometryProxy
    let viewModel: HomeViewModel
    let adService: AdService
    
    private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
    
    var body: some View {
        // Horizontal layout for main action buttons
        HStack(spacing: 12) {
            // Secondary retry button  
            Button(action: {
                viewModel.clearResult()
                
                let shouldShowAd = viewModel.shouldShowAd()
                let canShowAd = adService.canShowInterstitialAd
                
                if shouldShowAd && canShowAd {
                    Task { @MainActor in
                        await adService.showInterstitialAd {
                            // Execute rerun after ad is dismissed
                            DispatchQueue.main.async {
                                viewModel.rerunMeal()
                            }
                        }
                    }
                } else {
                    viewModel.rerunMeal()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("もう一度")
                        .fontWeight(.semibold)
                        .font(.system(size: 14))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Primary decision button (orange theme)
            DecisionButtonView(result: result, geometry: geometry, viewModel: viewModel)
        }
        .padding(.horizontal, 24)
    }
}

struct DecisionButtonView: View {
    let result: MealResult
    let geometry: GeometryProxy
    let viewModel: HomeViewModel
    
    private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
    
    var body: some View {
        Button(action: {
            handleDecisionAction()
        }) {
            HStack(spacing: 6) {
                Image(systemName: buttonIcon)
                    .font(.system(size: 14, weight: .semibold))
                Text(buttonText)
                    .fontWeight(.semibold)
                    .font(.system(size: 14))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [themeOrange, themeOrange.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .shadow(color: themeOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var buttonIcon: String {
        switch result.type {
        case .recipe:
            return "heart.fill"
        case .restaurant:
            return "location.fill"
        case .eatingOutMeal:
            return "magnifyingglass"
        }
    }
    
    private var buttonText: String {
        switch result.type {
        case .recipe:
            return "これに決定！"
        case .restaurant:
            return "このお店に！"
        case .eatingOutMeal:
            return "お店を探す！"
        }
    }
    
    private func handleDecisionAction() {
        if result.type == .eatingOutMeal, let eatingOutMeal = result.eatingOutMeal {
            // For eating out meals, search for restaurants
            viewModel.clearResult()
            viewModel.searchRestaurantsForEatingOut(with: eatingOutMeal)
        } else {
            // For recipes and restaurants, show congratulations
            let currentResult = viewModel.spinnerResult
            
            viewModel.clearResult()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let storedResult = currentResult {
                    viewModel.saveDecisionToHistory(with: storedResult)
                }
            }
        }
    }
}

struct AsyncImageView: View {
    let imageURL: String
    let resultType: MealResultType
    let frameHeight: CGFloat
    let iconSize: CGFloat
    
    private var fallbackGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [themeOrange.opacity(0.3), themeTeal.opacity(0.2)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var fallbackIcon: String {
        switch resultType {
        case .recipe:
            return "fork.knife"
        case .restaurant:
            return "building.2"
        case .eatingOutMeal:
            return "fork.knife.circle"
        }
    }
    
    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_), .empty:
                Rectangle()
                    .fill(fallbackGradient)
                    .overlay(
                        Image(systemName: fallbackIcon)
                            .font(.system(size: iconSize))
                            .foregroundColor(.white)
                    )
            @unknown default:
                ProgressView()
            }
        }
        .frame(height: frameHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
} 
