import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let initialServings: Int? // Person count from HomeView
    @State private var isBookmarked = false
    @State private var userRating: Int = 0
    @State private var showingShareSheet = false
    @State private var scaledServings: Int
    @State private var checkedIngredients: Set<String> = []
    @State private var actualPopularityCount: Int = 0
    @State private var isLoadingRating = false
    @State private var averageRating: Double = 0.0
    @State private var ratingCount: Int = 0
    @State private var isLoadingAverageRating = false
    
    // Theme colors
    private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
    private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)
    
    init(recipe: Recipe, initialServings: Int? = nil) {
        self.recipe = recipe
        self.initialServings = initialServings
        // Use initialServings from HomeView if provided, otherwise use recipe's default servings
        self._scaledServings = State(initialValue: initialServings ?? recipe.servings)
        self._actualPopularityCount = State(initialValue: recipe.popularityCount)
    }

    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Hero Image Section with Overlay
                heroImageSection
                
                // Content Container
                VStack(spacing: 24) {
                    // Title and Basic Info
                    titleSection
                    
                    // Meta Information Cards
                    metaInfoSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    // Servings Adjuster
                    servingsAdjusterSection
                    
                    // Ingredients Section
                    ingredientsSection
                    
                    // Instructions Section
                    instructionsSection
                    
                    // Nutrition Section
                    nutritionSection
                    
                    // Rating Section
                    ratingSection
                    
                    // Legal Disclaimer Section
                    disclaimerSection
                    
                    // Bottom Spacing
                    Color.clear.frame(height: 20)
                }
                .padding(.horizontal, 20)
                .background(Color(.systemBackground))
                .clipShape(
                    RoundedRectangle(cornerRadius: 24)
                )
                .offset(y: -24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBookmarkStatus()
            loadActualPopularityCount()
            loadExistingRating()
            loadAverageRating()
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(recipe: recipe)
        }
    }
    
    private var heroImageSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Image
            if let imageURL = recipe.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(.systemGray5), Color(.systemGray6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                        )
                }
                .frame(height: 320)
                .clipped()
            }
            
            // Gradient Overlay
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 320)
            
            // Popularity Badge
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                                .font(.caption)
                            Text("\(actualPopularityCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                        
                        Text(LocalizedString("popularity_label"))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
            }
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .padding(.top, 20) // Increased top spacing
            
            // みんなの評価 section (moved here from rating section)
            publicRatingSection
            
            // Diet Tags
            if !recipe.dietTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recipe.dietTags, id: \.self) { tag in
                            Text(LocalizedString(tag))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(themeTeal.opacity(0.15))
                                        .overlay(
                                            Capsule()
                                                .stroke(themeTeal.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(themeTeal)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
    
    private var metaInfoSection: some View {
        HStack(spacing: 16) {
            // Time Card
            metaCard(
                icon: "clock.fill",
                value: "\(recipe.totalTime)分",
                label: "調理時間",
                color: themeTeal
            )
            
            // Cost Card (scaled based on person count)
            if recipe.estimatedCost > 0 {
                let scaledCost = recipe.scaledCost(for: scaledServings)
                metaCard(
                    icon: "yensign.circle.fill",
                    value: "¥\(scaledCost)",
                    label: "目安費用",
                    color: themeOrange
                )
            }
            
            // Cuisine Card
            metaCard(
                icon: "globe.asia.australia.fill",
                value: recipe.cuisine.isEmpty ? "その他" : recipe.cuisine,
                label: "料理系統",
                color: themeOrange
            )
        }
    }
    
    private func metaCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6).opacity(0.5))
        )
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Bookmark Button
            Button(action: {
                toggleBookmark()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isBookmarked ? "heart.fill" : "heart")
                        .font(.title3)
                        .foregroundColor(isBookmarked ? .white : themeOrange)
                    Text(isBookmarked ? LocalizedString("favorited") : LocalizedString("add_to_favorites"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isBookmarked ? .white : themeOrange)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isBookmarked ? themeOrange : themeOrange.opacity(0.1))
                )
            }
            
            // Share Button
            Button(action: {
                showingShareSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    Text(LocalizedString("share_on_sns"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(themeTeal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeTeal.opacity(0.1))
                )
            }
        }
    }
    
    private var servingsAdjusterSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedString("person_count_adjustment"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(String(format: LocalizedString("person_count_display"), scaledServings))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 0) {
                    Button(action: {
                        if scaledServings > 1 {
                            scaledServings -= 1
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.title3)
                            .foregroundColor(scaledServings <= 1 ? .gray : .white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(scaledServings <= 1 ? Color(.systemGray5) : themeTeal)
                            )
                    }
                    .disabled(scaledServings <= 1)
                    
                    Text("\(scaledServings)")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 60)
                    
                    Button(action: {
                        if scaledServings < 10 {
                            scaledServings += 1
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(scaledServings >= 10 ? .gray : .white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(scaledServings >= 10 ? Color(.systemGray5) : themeTeal)
                            )
                    }
                    .disabled(scaledServings >= 10)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.title2)
                    .foregroundColor(themeOrange)
                
                Text(LocalizedString("ingredients"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: LocalizedString("items_count"), scaledIngredients.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
            }
            
            LazyVStack(spacing: 12) {
                ForEach(scaledIngredients.indices, id: \.self) { index in
                    let ingredient = scaledIngredients[index]
                    HStack(alignment: .top, spacing: 16) {
                        // Ingredient Number
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundColor(themeOrange)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(themeOrange.opacity(0.15))
                            )
                        
                        // Ingredient Description
                        Text(ingredient)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(themeTeal)
                
                Text(LocalizedString("instructions"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: LocalizedString("steps_count"), recipe.instructions.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
            }
            
            LazyVStack(spacing: 16) {
                ForEach(recipe.instructions.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 16) {
                        // Step Number
                        Text("\(index + 1)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [themeTeal, themeTeal.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        
                        // Instruction Text
                        Text(recipe.instructions[index])
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    private var nutritionSection: some View {
        let scaledNutrition = recipe.scaledNutrition(for: scaledServings)
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundColor(themeOrange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("栄養成分")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("\(scaledServings)人前あたり")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Basic Macronutrients
            VStack(alignment: .leading, spacing: 12) {
                Text("基本栄養素")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                    nutritionCard(
                        icon: "flame.fill",
                        value: "\(max(0, scaledNutrition.calories))",
                        unit: "kcal",
                        label: "エネルギー",
                        color: themeOrange
                    )
                    
                    nutritionCard(
                        icon: "leaf.fill",
                        value: String(format: "%.1f", max(0.0, scaledNutrition.protein)),
                        unit: "g",
                        label: "タンパク質",
                        color: themeTeal
                    )
                    
                    nutritionCard(
                        icon: "drop.fill",
                        value: String(format: "%.1f", max(0.0, scaledNutrition.fat)),
                        unit: "g",
                        label: "脂質",
                        color: themeOrange
                    )
                    
                    nutritionCard(
                        icon: "waveform.path.ecg",
                        value: String(format: "%.1f", max(0.0, scaledNutrition.fiber)),
                        unit: "g",
                        label: "食物繊維",
                        color: themeTeal
                    )
                    
                    nutritionCard(
                        icon: "square.stack.3d.up.fill",
                        value: String(format: "%.1f", max(0.0, scaledNutrition.carbs)),
                        unit: "g",
                        label: "糖質",
                        color: themeOrange
                    )
                    
                    nutritionCard(
                        icon: "drop.triangle.fill",
                        value: "\(max(0, scaledNutrition.sodium))",
                        unit: "mg",
                        label: "ナトリウム",
                        color: themeTeal
                    )
                    
                    nutritionCard(
                        icon: "heart.circle",
                        value: "\(max(0, scaledNutrition.cholesterol))",
                        unit: "mg",
                        label: "コレステロール",
                        color: themeOrange
                    )
                    
                    nutritionCard(
                        icon: "drop.triangle",
                        value: String(format: "%.1f", max(0.0, scaledNutrition.saturatedFat)),
                        unit: "g",
                        label: "飽和脂肪酸",
                        color: themeTeal
                    )
                }
            }
        }
        .id("nutrition-\(recipe.id)-\(scaledServings)") // Add unique ID to prevent reuse issues
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    private func nutritionCard(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // Simple public rating section for title area
    private var publicRatingSection: some View {
        HStack(spacing: 8) {
            if ratingCount > 0 {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
                            .foregroundColor(star <= Int(averageRating.rounded()) ? .yellow : .gray)
                            .font(.caption)
                    }
                }
                
                Text(String(format: "%.1f", averageRating))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("(\(ratingCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { _ in
                        Image(systemName: "star")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                }
                
                Text("未評価")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundColor(themeOrange)
                
                Text(LocalizedString("rate_this_recipe"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoadingRating || isLoadingAverageRating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            

            
            // User Rating Section
            VStack(alignment: .leading, spacing: 12) {
                Text("あなたの評価")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= userRating ? "star.fill" : "star")
                            .foregroundColor(star <= userRating ? themeOrange : .gray)
                            .font(.title)
                            .onTapGesture {
                                saveRating(star)
                            }
                    }
                }
                
                if userRating > 0 {
                    VStack(spacing: 8) {
                        Text(LocalizedString("thank_you_for_rating"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(themeOrange.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(themeOrange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        Text("このレシピの評価が保存されました")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    // MARK: - Disclaimer Section
    private var disclaimerSection: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal, 20)
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.caption)
                
                Text("レシピ情報は参考目安です。アレルギーや健康被害について当開発者は責任を負いません。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func loadBookmarkStatus() {
        // Check if this recipe is bookmarked
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        FirebaseService.shared.isBookmarked(type: "recipe", itemId: recipe.id, userId: userId) { isBookmarked in
            DispatchQueue.main.async {
                self.isBookmarked = isBookmarked
            }
        }
    }
    
    private func toggleBookmark() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        if isBookmarked {
            FirebaseService.shared.removeBookmark(type: "recipe", itemId: recipe.id, userId: userId) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self.isBookmarked = false
                    }
                }
            }
        } else {
            FirebaseService.shared.addBookmark(type: "recipe", itemId: recipe.id, userId: userId) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self.isBookmarked = true
                    }
                }
            }
        }
    }
    
    private func loadActualPopularityCount() {
        FirebaseService.shared.getRecipePopularity(recipeId: recipe.id) { count, error in
            if let count = count {
                self.actualPopularityCount = count
            }
        }
    }
    
    private func loadExistingRating() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        isLoadingRating = true
        
        // Load existing rating from history entries for this recipe
        FirebaseService.shared.getHistoryEntries(userId: userId) { entries, error in
            DispatchQueue.main.async {
                self.isLoadingRating = false
                
                if error == nil {
                    // Find the most recent history entry for this recipe that has a rating
                    let recipeEntries = entries.filter { 
                        $0.resultType == "recipe" && $0.resultId == self.recipe.id 
                    }
                    
                    // Get the most recent rating given to this recipe
                    let sortedEntries = recipeEntries.sorted { $0.timestamp > $1.timestamp }
                    if let mostRecentRating = sortedEntries.first(where: { $0.rating != nil })?.rating {
                        self.userRating = Int(mostRecentRating)
                        print("✅ Loaded existing rating for recipe \(self.recipe.title): \(self.userRating) stars")
                    }
                } else if let error = error {
                    print("❌ Failed to load existing rating: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveRating(_ rating: Int) {
        guard let userId = AuthService.shared.currentUser?.id else { 
            print("❌ No user logged in")
            return 
        }
        
        // Update local state immediately
        userRating = rating
        isLoadingRating = true
        
        // Find and update all history entries for this recipe
        FirebaseService.shared.getHistoryEntries(userId: userId) { entries, error in
            DispatchQueue.main.async {
                if error == nil {
                    let recipeEntries = entries.filter { 
                        $0.resultType == "recipe" && $0.resultId == self.recipe.id 
                    }
                    
                    let group = DispatchGroup()
                    var updateSuccessful = true
                    
                    // Update all history entries for this recipe
                    for entry in recipeEntries {
                        group.enter()
                        FirebaseService.shared.updateHistoryEntryRating(
                            id: entry.id, 
                            userId: userId, 
                            rating: Double(rating)
                        ) { error in
                            if error != nil {
                                updateSuccessful = false
                                print("❌ Failed to update history entry rating: \(error?.localizedDescription ?? "Unknown error")")
                            }
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: .main) {
                        self.isLoadingRating = false
                        if updateSuccessful {
                            print("✅ Recipe rating saved successfully to all history entries")
                            // Save rating to global ratings collection
                            self.saveGlobalRating(for: self.recipe.id, rating: Double(rating), type: "recipe")
                            // Notify other views to refresh
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshHistory"), object: nil)
                        }
                    }
                    
                } else if let error = error {
                    self.isLoadingRating = false
                    print("❌ Failed to get history entries for rating update: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadAverageRating() {
        isLoadingAverageRating = true
        
        FirebaseService.shared.getAverageRating(itemId: recipe.id, itemType: "recipe") { average, count, error in
            DispatchQueue.main.async {
                self.isLoadingAverageRating = false
                if error == nil {
                    self.averageRating = average
                    self.ratingCount = count
                    print("✅ Loaded average rating for recipe: \(average) (\(count) ratings)")
                } else if let error = error {
                    print("❌ Failed to load average rating: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveGlobalRating(for itemId: String, rating: Double, type: String) {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        FirebaseService.shared.saveGlobalRating(itemId: itemId, itemType: type, userId: userId, rating: rating, comment: "") { error in
            if error == nil {
                print("✅ Global rating saved successfully")
                // Reload average rating to show updated stats
                DispatchQueue.main.async {
                    self.loadAverageRating()
                }
            } else if let error = error {
                print("❌ Failed to save global rating: \(error.localizedDescription)")
            }
        }
    }
    
    private var scaledIngredients: [String] {
        let ratio = Double(scaledServings) / Double(recipe.servings)
        return recipe.ingredients.map { ingredient in
            // Scale numeric amounts in ingredient descriptions using regex
            let pattern = "\\d+(?:\\.\\d+)?"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return ingredient
            }
            
            let range = NSRange(location: 0, length: ingredient.utf16.count)
            var result = ingredient
            
            // Find and replace numbers
            let matches = regex.matches(in: ingredient, options: [], range: range)
            for match in matches.reversed() {
                guard let matchRange = Range(match.range, in: ingredient) else { continue }
                let matchedString = String(ingredient[matchRange])
                
                if let number = Double(matchedString) {
                    let scaledNumber = number * ratio
                    let formattedNumber = String(format: scaledNumber.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", scaledNumber)
                    result = result.replacingCharacters(in: matchRange, with: formattedNumber)
                }
            }
            
            return result
        }
    }
}



struct ShareSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    // Theme colors
    private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
    private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(NSLocalizedString("share_recipe", comment: "Share recipe"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    Button(action: {
                        shareToSocialMedia()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("SNSでシェア")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeTeal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        copyRecipeLink()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text(NSLocalizedString("copy_link", comment: "Copy link"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeOrange.opacity(0.1))
                        .foregroundColor(themeOrange)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareToSocialMedia() {
        let shareText = "MealDeciderで見つけたレシピ: \(recipe.title)"
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
        
        dismiss()
    }
    
    private func copyRecipeLink() {
        let recipeLink = "https://mealDecider.app/recipe/\(recipe.id)"
        UIPasteboard.general.string = recipeLink
        dismiss()
    }
}

struct RecipeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RecipeDetailView(recipe: Recipe.sample)
        }
    }
}

extension Recipe {
    static let sample = Recipe(
        data: [
            "name": "サンプルレシピ",
            "description": "これはサンプルのレシピです",
            "ingredients": ["材料1", "材料2", "材料3"],
            "instructions": ["手順1", "手順2", "手順3"],
            "cookTime": 30,
            "servings": 4,
            "difficulty": "easy",
            "cuisine": "和食",
            "estimatedCost": 500,
            "tags": ["簡単", "和食"],
            "nutrition": [
                "calories": 250,
                "protein": 15,
                "carbs": 30,
                "fat": 8
            ],
            "popularityCount": 42
        ],
        id: "sample"
    )
}

 