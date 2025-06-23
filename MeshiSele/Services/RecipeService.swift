import Foundation
import FirebaseFirestore

class RecipeService: ObservableObject {
    static let shared = RecipeService()
    
    private let db = Firestore.firestore()
    
    // Thread safety
    private let dbQueue = DispatchQueue(label: "com.meshisele.recipeservice.db", qos: .userInitiated)
    
    private init() {
        // Log Firebase configuration
        print("🔧 Firebase: Initializing RecipeService")
        print("🔧 Firebase: Firestore app: \(db.app.name)")
        print("🔧 Firebase: Firestore settings: \(db.settings)")
        
        // Test basic connectivity
        testFirebaseConnection()
    }
    
    private func testFirebaseConnection() {
        print("🔧 Firebase: Testing basic connectivity...")
        db.collection("recipes").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firebase Connection Test FAILED: \(error.localizedDescription)")
            } else if let snapshot = snapshot {
                print("✅ Firebase Connection Test SUCCESS: \(snapshot.documents.count) documents accessible")
                if let firstDoc = snapshot.documents.first {
                    let data = firstDoc.data()
                    print("📄 Sample document (\(firstDoc.documentID)):")
                    print("  - title: \(data["title"] ?? "N/A")")
                    print("  - dietTags: \(data["dietTags"] ?? [])")
                    print("  - cuisine: \(data["cuisine"] ?? "N/A")")
                }
            } else {
                print("⚠️ Firebase Connection Test: Unexpected nil snapshot")
            }
        }
    }
    
    // Debug method to test Firebase query with specific parameters
    func debugFirebaseQuery() {
        print("=== FIREBASE DEBUG TEST STARTING ===")
        print("🔧 DEBUG: Testing Firebase query with 'all' diet filter...")
        
        // First test basic Firebase connectivity
        print("🔧 DEBUG: Testing basic collection access...")
        db.collection("recipes").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("❌ DEBUG: Basic collection access FAILED: \(error.localizedDescription)")
            } else if let snapshot = snapshot {
                print("✅ DEBUG: Basic collection access SUCCESS: \(snapshot.documents.count) documents")
                if let firstDoc = snapshot.documents.first {
                    print("📄 DEBUG: Sample document ID: \(firstDoc.documentID)")
                    let data = firstDoc.data()
                    print("📄 DEBUG: Sample document data keys: \(Array(data.keys))")
                }
            }
        }
        
        // Then test the actual recipe fetch
        fetchRandomRecipe(
            dietFilter: "all",
            cuisine: nil,
            specifiedIngredients: nil,
            isRandom: true,
            excludedIngredients: [],
            excludedAllergens: [],
            budget: .noLimit,
            maxTime: .noLimit
        ) { recipe in
            if let recipe = recipe {
                print("✅ DEBUG: Successfully got recipe: \(recipe.title)")
            } else {
                print("❌ DEBUG: Failed to get recipe from Firebase")
            }
            print("=== FIREBASE DEBUG TEST COMPLETED ===")
        }
    }
    
    func fetchRandomRecipe(
        dietFilter: String,
        cuisine: String?,
        specifiedIngredients: [String]?,
        isRandom: Bool,
        excludedIngredients: [String],
        excludedAllergens: [String],
        budget: BudgetOption,
        maxTime: CookTimeOption,
        completion: @escaping (Recipe?) -> Void
    ) {
        // 🔍 DETAILED LOGGING: Input parameters
        print("🔍 RecipeService.fetchRandomRecipe called with:")
        print("  - dietFilter: '\(dietFilter)'")
        print("  - cuisine: \(cuisine ?? "nil")")
        print("  - specifiedIngredients: \(specifiedIngredients ?? [])")
        print("  - isRandom: \(isRandom)")
        print("  - excludedIngredients: \(excludedIngredients)")
        print("  - excludedAllergens: \(excludedAllergens)")
        print("  - budget: \(budget)")
        print("  - maxTime: \(maxTime)")
        
        dbQueue.async { [weak self] in
            guard let self = self else {
                print("❌ RecipeService: self is nil")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            print("🔥 Firebase: Starting query on 'recipes' collection")
            
            var query: Query = self.db.collection("recipes")
            
            // Only use dietTags arrayContains if dietFilter is not 'all' and no specific ingredients are provided
            // This avoids the multiple array operation limitation
            let hasSpecificIngredients = !isRandom && specifiedIngredients?.isEmpty == false
            
            if dietFilter != "all" && !hasSpecificIngredients {
                print("🔥 Firebase: Primary filter - dietTags arrayContains: '\(dietFilter)'")
                query = query.whereField("dietTags", arrayContains: dietFilter)
            } else if hasSpecificIngredients {
                print("🔥 Firebase: Skipping dietTags filter to avoid multiple array operations")
                print("🔥 Firebase: Will filter diet tags client-side")
            } else {
                print("🔥 Firebase: No dietTags filter applied (dietFilter is 'all')")
            }
            
            // Cuisine constraint
            if let cuisine = cuisine {
                if cuisine == "すべて" {
                    // "すべて" means show all cuisines, so no cuisine filter
                    print("🔥 Firebase: No cuisine filter applied (すべて selected)")
                } else if cuisine == "その他" {
                    // "その他" means exclude the main cuisine categories (和食、洋食、中華、イタリアン、韓国、フレンチ)
                    let mainCuisines = ["和食", "洋食", "中華", "イタリアン", "韓国", "フレンチ"]
                    print("🔥 Firebase: Adding その他 filter - cuisine not in: \(mainCuisines)")
                    // Note: For recipes, we need to check the actual cuisine field values in the database
                    // Since recipes store cuisine as display names, we filter by display names
                    query = query.whereField("cuisine", notIn: mainCuisines)
                } else {
                    print("🔥 Firebase: Adding cuisine filter - cuisine isEqualTo: '\(cuisine)'")
                    query = query.whereField("cuisine", isEqualTo: cuisine)
                }
            }
            
            // Budget constraint - Handle both total cost recipes and per-serving cost recipes
            // The database contains mixed formats: some recipes store total cost, others store per-serving cost
            switch budget {
            case .under500:
                // Accept recipes with total cost <= 2000 (4 servings * 500) or per-serving cost <= 500
                print("🔥 Firebase: Adding budget filter - estimatedCost <= 2000")
                query = query.whereField("estimatedCost", isLessThanOrEqualTo: 2000)
            case .between500_1000:
                // Accept recipes in range 500-4000 to cover both total and per-serving cost formats
                print("🔥 Firebase: Adding budget filter - estimatedCost > 500 AND <= 4000")
                query = query
                    .whereField("estimatedCost", isGreaterThan: 500)
                    .whereField("estimatedCost", isLessThanOrEqualTo: 4000)
            case .between1000_1500:
                // Accept recipes in range 1000-6000 to cover both formats
                // This includes 1-serving premium recipes (1000-1500) and multi-serving recipes (up to 6000 total)
                print("🔥 Firebase: Adding budget filter - estimatedCost > 1000 AND <= 6000")
                query = query
                    .whereField("estimatedCost", isGreaterThan: 1000)
                    .whereField("estimatedCost", isLessThanOrEqualTo: 6000)
            case .custom(let min, let max):
                // Convert per-serving budget to accommodate both formats
                let totalMin = min > 0 ? min : 0
                let totalMax = max // Max possible servings for multi-serving recipes
                print("🔥 Firebase: Adding custom budget filter - estimatedCost >= \(totalMin) AND <= \(totalMax)")
                if totalMin > 0 {
                    query = query.whereField("estimatedCost", isGreaterThanOrEqualTo: totalMin)
                }
                query = query.whereField("estimatedCost", isLessThanOrEqualTo: totalMax)
            case .noLimit:
                print("🔥 Firebase: No budget filter applied")
                break
            }
            
            // Note: totalTime filtering moved to client-side to avoid multiple range filters in Firebase query
            
            // If specific ingredients are provided and not random mode, use arrayContainsAny
            // But only if we didn't already use arrayContains for dietTags
            if hasSpecificIngredients, let ingredients = specifiedIngredients {
                // Use arrayContainsAny to find recipes with at least one specified ingredient
                print("🔥 Firebase: Adding ingredient filter - ingredientTags arrayContainsAny: \(ingredients)")
                query = query.whereField("ingredientTags", arrayContainsAny: ingredients)
            } else {
                print("🔥 Firebase: No ingredient filter applied (isRandom: \(isRandom), ingredients: \(specifiedIngredients ?? []))")
            }
            
            // Execute query
            self.executeRecipeQuery(
                query: query, 
                excludedIngredients: excludedIngredients, 
                excludedAllergens: excludedAllergens, 
                isRandom: isRandom, 
                specifiedIngredients: specifiedIngredients,
                dietFilter: dietFilter,
                cuisine: cuisine,
                budget: budget,
                maxTime: maxTime,
                completion: completion
            )
        }
    }
    
    // Fetch specific recipe by ID
    func fetchRecipe(id: String, completion: @escaping (Recipe?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            self.db.collection("recipes").document(id).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    guard let data = snapshot?.data(), error == nil else {
                        completion(nil)
                        return
                    }
                    
                    let recipe = Recipe(data: data, id: id)
                    completion(recipe)
                }
            }
        }
    }
    
    // Fetch recipes by IDs (for bookmarks)
    func fetchRecipes(ids: [String], completion: @escaping ([Recipe]) -> Void) {
        guard !ids.isEmpty else {
            DispatchQueue.main.async { completion([]) }
            return
        }
        
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Firestore 'in' queries are limited to 10 items
            let chunks = ids.chunked(into: 10)
            var allRecipes: [Recipe] = []
            let group = DispatchGroup()
            
            for chunk in chunks {
                group.enter()
                self.db.collection("recipes")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments { snapshot, error in
                        defer { group.leave() }
                        
                        guard let docs = snapshot?.documents, error == nil else {
                            return
                        }
                        
                        let recipes = docs.compactMap { doc in
                            Recipe(data: doc.data(), id: doc.documentID)
                        }
                        
                        allRecipes.append(contentsOf: recipes)
                    }
            }
            
            group.notify(queue: .main) {
                completion(allRecipes)
            }
        }
    }
    
    // Search recipes by title (for search functionality)
    func searchRecipes(query: String, completion: @escaping ([Recipe]) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Simple text search - in production, you'd want to use something like Algolia
            self.db.collection("recipes")
                .order(by: "title")
                .start(at: [query])
                .end(at: [query + "\u{f8ff}"])
                .limit(to: 20)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        guard let docs = snapshot?.documents, error == nil else {
                            completion([])
                            return
                        }
                        
                        let recipes = docs.compactMap { doc in
                            Recipe(data: doc.data(), id: doc.documentID)
                        }
                        
                        completion(recipes)
                    }
                }
        }
    }
    
    private func executeRecipeQuery(
        query: Query, 
        excludedIngredients: [String], 
        excludedAllergens: [String],
        isRandom: Bool,
        specifiedIngredients: [String]?,
        dietFilter: String,
        cuisine: String?,
        budget: BudgetOption,
        maxTime: CookTimeOption,
        completion: @escaping (Recipe?) -> Void
    ) {
        // Add timeout mechanism to prevent hanging requests
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            print("⚠️ RecipeService: Query timeout, using fallback recipes")
            self?.getFallbackRecipe(
                dietFilter: dietFilter,
                cuisine: cuisine,
                specifiedIngredients: specifiedIngredients,
                isRandom: isRandom,
                excludedIngredients: excludedIngredients,
                excludedAllergens: excludedAllergens,
                budget: budget,
                maxTime: maxTime,
                completion: completion
            )
        }
        
        // Set 8 second timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0, execute: timeoutWorkItem)
        
        print("🔥 Firebase: Executing query...")
        
        query.getDocuments { snapshot, error in
            // Cancel timeout if request completes
            timeoutWorkItem.cancel()
            
            DispatchQueue.main.async {
                print("🔥 Firebase: Query completed")
                
                // Check for specific network errors
                if let error = error {
                    print("❌ Firebase ERROR: \(error)")
                    print("❌ Firebase ERROR Type: \(type(of: error))")
                    if let nsError = error as NSError? {
                        print("❌ Firebase ERROR Code: \(nsError.code)")
                        print("❌ Firebase ERROR Domain: \(nsError.domain)")
                        print("❌ Firebase ERROR UserInfo: \(nsError.userInfo)")
                    }
                    
                    if error.localizedDescription.contains("network") || 
                       error.localizedDescription.contains("connection") ||
                       error.localizedDescription.contains("timeout") {
                        print("🌐 RecipeService: Network connectivity issue, using fallback")
                    }
                    self.getFallbackRecipe(
                        dietFilter: dietFilter,
                        cuisine: cuisine,
                        specifiedIngredients: specifiedIngredients,
                        isRandom: isRandom,
                        excludedIngredients: excludedIngredients,
                        excludedAllergens: excludedAllergens,
                        budget: budget,
                        maxTime: maxTime,
                        completion: completion
                    )
                    return
                }
                
                // If we have database results, use them
                if let docs = snapshot?.documents, !docs.isEmpty {
                    print("✅ Firebase SUCCESS: Found \(docs.count) documents")
                    print("📄 Firebase: Document IDs: \(docs.map { $0.documentID })")
                    
                    // Log first few documents for debugging
                    for (index, doc) in docs.prefix(3).enumerated() {
                        let data = doc.data()
                        print("📄 Document \(index + 1) (\(doc.documentID)):")
                        print("  - title: \(data["title"] ?? "N/A")")
                        print("  - dietTags: \(data["dietTags"] ?? [])")
                        print("  - cuisine: \(data["cuisine"] ?? "N/A")")
                        print("  - estimatedCost: \(data["estimatedCost"] ?? "N/A")")
                        print("  - ingredientTags: \((data["ingredientTags"] as? [String] ?? []).prefix(5))")
                    }
                    
                    // Original database logic with client-side diet filtering when needed
                    let afterExclusion = docs.compactMap { doc -> Recipe? in
                        let data = doc.data()
                        let tags = data["ingredientTags"] as? [String] ?? []
                        let recipeDietTags = data["dietTags"] as? [String] ?? []
                        
                        let recipe = Recipe(data: data, id: doc.documentID)
                        
                        // Check excluded ingredients
                        if excludedIngredients.contains(where: { tags.contains($0) }) {
                            return nil
                        }
                        
                        // Client-side diet filtering if we skipped it in Firebase query
                        let hasSpecificIngredients = !isRandom && specifiedIngredients?.isEmpty == false
                        if dietFilter != "all" && hasSpecificIngredients {
                            // We skipped dietTags filter in Firebase, so apply it here
                            if !recipeDietTags.contains(dietFilter) {
                                return nil
                            }
                        }
                        
                        // Check excluded allergens
                        if recipe.containsAllergens(excludedAllergens) {
                            return nil
                        }
                        
                        // Check cooking time constraint (client-side filtering)
                        if let maxMinutes = maxTime.maxMinutes, recipe.totalTime > maxMinutes {
                            print("⏰ Recipe '\(recipe.title)' excluded: \(recipe.totalTime) minutes > \(maxMinutes) minute limit")
                            return nil
                        }
                        return recipe
                    }
                    
                    print("🔍 After exclusion filtering: \(afterExclusion.count) recipes remain")
                    
                    guard !afterExclusion.isEmpty else {
                        print("❌ No recipes remain after exclusion filters, using fallback")
                        // If no results after exclusion, use fallback
                        self.getFallbackRecipe(
                            dietFilter: dietFilter,
                            cuisine: cuisine,
                            specifiedIngredients: specifiedIngredients,
                            isRandom: isRandom,
                            excludedIngredients: excludedIngredients,
                            excludedAllergens: excludedAllergens,
                            budget: budget,
                            maxTime: maxTime,
                            completion: completion
                        )
                        return
                    }
                    
                    let finalCandidates: [Recipe]
                    
                    if !isRandom, let ingredients = specifiedIngredients, !ingredients.isEmpty {
                        let allMatch = afterExclusion.filter { recipe in
                            ingredients.allSatisfy { ingredient in
                                recipe.ingredientTags.contains(ingredient)
                            }
                        }
                        
                        finalCandidates = !allMatch.isEmpty ? allMatch : afterExclusion
                    } else {
                        finalCandidates = afterExclusion
                    }
                    
                    let randomIndex = Int.random(in: 0..<finalCandidates.count)
                    completion(finalCandidates[randomIndex])
                } else {
                    // No database results, use fallback recipes
                    print("❌ Firebase: No documents found in query result")
                    if let snapshot = snapshot {
                        print("📊 Firebase: Snapshot exists but is empty")
                        print("📊 Firebase: Snapshot.isEmpty: \(snapshot.isEmpty)")
                        print("📊 Firebase: Snapshot.count: \(snapshot.count)")
                        print("📊 Firebase: Snapshot.documents.count: \(snapshot.documents.count)")
                    } else {
                        print("📊 Firebase: Snapshot is nil")
                    }
                    print("📱 RecipeService: No Firebase results found, using fallback recipes")
                    self.getFallbackRecipe(
                        dietFilter: dietFilter,
                        cuisine: cuisine,
                        specifiedIngredients: specifiedIngredients,
                        isRandom: isRandom,
                        excludedIngredients: excludedIngredients,
                        excludedAllergens: excludedAllergens,
                        budget: budget,
                        maxTime: maxTime,
                        completion: completion
                    )
                }
            }
        }
    }
    
    private func getFallbackRecipe(
        dietFilter: String,
        cuisine: String?,
        specifiedIngredients: [String]?,
        isRandom: Bool,
        excludedIngredients: [String],
        excludedAllergens: [String],
        budget: BudgetOption,
        maxTime: CookTimeOption,
        completion: @escaping (Recipe?) -> Void
    ) {
        print("📱 RecipeService: Using fallback recipes with artificial delay")
        print("📱 RecipeService: Fallback parameters - dietFilter: '\(dietFilter)', cuisine: \(cuisine ?? "nil"), ingredients: \(specifiedIngredients ?? []), isRandom: \(isRandom)")
        
        // Add immediate debug logging before the delay
        if let cuisine = cuisine, cuisine == "その他" {
            print("🔍 IMMEDIATE DEBUG: その他 was selected, about to apply fallback logic")
            let allFallbackRecipes = createFallbackJapaneseRecipes()
            print("🔍 IMMEDIATE DEBUG: Total fallback recipes: \(allFallbackRecipes.count)")
                    let mainCuisines = ["和食", "洋食", "中華", "イタリアン", "韓国", "フレンチ"]
        let nonMainCuisines = allFallbackRecipes.filter { !mainCuisines.contains($0.cuisine) }
            print("🔍 IMMEDIATE DEBUG: Recipes NOT in main cuisines: \(nonMainCuisines.count)")
            for recipe in nonMainCuisines {
                print("🔍 IMMEDIATE DEBUG: - \(recipe.title): \(recipe.cuisine)")
            }
            let mainCuisineRecipes = allFallbackRecipes.filter { mainCuisines.contains($0.cuisine) }
            print("🔍 IMMEDIATE DEBUG: Recipes IN main cuisines: \(mainCuisineRecipes.count)")
            for recipe in mainCuisineRecipes {
                print("🔍 IMMEDIATE DEBUG: - \(recipe.title): \(recipe.cuisine)")
            }
        }
        
        // Simulate Firebase delay for UX consistency
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("📱 RecipeService: Returning fallback recipe after delay")
            let allFallbackRecipes = self.createFallbackJapaneseRecipes()
            
            // Apply filters
            var filteredRecipes = allFallbackRecipes
            
            // Filter by cuisine if specified
            if let cuisine = cuisine {
                if cuisine == "すべて" {
                    // "すべて" means show all cuisines, so no filtering needed
                    print("📱 RecipeService: No cuisine filtering applied (すべて selected)")
                } else if cuisine == "その他" {
                    // "その他" means exclude the main cuisine categories (和食、洋食、中華、イタリアン、韓国、フレンチ)
                    let mainCuisines = ["和食", "洋食", "中華", "イタリアン", "韓国", "フレンチ"]
                    print("📱 RecipeService: Filtering for その他 - excluding: \(mainCuisines)")
                    print("📱 RecipeService: Before filtering: \(filteredRecipes.count) recipes")
                    
                    // Debug: print all cuisine values before filtering
                    let allCuisines = Set(filteredRecipes.map { $0.cuisine })
                    print("📱 RecipeService: All available cuisines: \(allCuisines)")
                    
                    filteredRecipes = filteredRecipes.filter { !mainCuisines.contains($0.cuisine) }
                    print("📱 RecipeService: After その他 filtering: \(filteredRecipes.count) recipes")
                    
                    // Debug: print remaining cuisines after filtering
                    let remainingCuisines = Set(filteredRecipes.map { $0.cuisine })
                    print("📱 RecipeService: Remaining cuisines: \(remainingCuisines)")
                } else {
                    print("📱 RecipeService: Filtering for specific cuisine: \(cuisine)")
                filteredRecipes = filteredRecipes.filter { $0.cuisine == cuisine }
                    print("📱 RecipeService: After cuisine filtering: \(filteredRecipes.count) recipes")
                }
            }
            
            // Filter by diet tags
            if dietFilter != "all" {
                print("📱 RecipeService: Before diet filtering (\(dietFilter)): \(filteredRecipes.count) recipes")
                filteredRecipes = filteredRecipes.filter { recipe in
                    // A recipe matches if it contains the specific diet tag OR contains "all"
                    let matches = recipe.dietTags.contains(dietFilter) || recipe.dietTags.contains("all")
                    if !matches {
                        print("📱 RecipeService: Recipe '\(recipe.title)' filtered out - dietTags: \(recipe.dietTags)")
                    }
                    return matches
                }
                print("📱 RecipeService: After diet filtering (\(dietFilter)): \(filteredRecipes.count) recipes")
            } else {
                print("📱 RecipeService: No diet filtering applied (dietFilter is 'all')")
            }
            
            // Filter by budget (handle both per-serving and total cost formats)
            switch budget {
            case .under500:
                filteredRecipes = filteredRecipes.filter { 
                    let perServingCost = $0.scaledCost(for: 1)
                    return perServingCost <= 500
                }
            case .between500_1000:
                filteredRecipes = filteredRecipes.filter { 
                    let perServingCost = $0.scaledCost(for: 1)
                    return perServingCost > 500 && perServingCost <= 1000 
                }
            case .between1000_1500:
                filteredRecipes = filteredRecipes.filter { 
                    let perServingCost = $0.scaledCost(for: 1)
                    return perServingCost > 1000 && perServingCost <= 1500 
                }
            case .custom(let min, let max):
                filteredRecipes = filteredRecipes.filter { 
                    let perServingCost = $0.scaledCost(for: 1)
                    return (min <= 0 || perServingCost >= min) && perServingCost <= max
                }
            case .noLimit:
                break
            }
            
            // Filter by cooking time
            if let maxMinutes = maxTime.maxMinutes {
                filteredRecipes = filteredRecipes.filter { $0.totalTime <= maxMinutes }
            }
            
            // Filter by excluded ingredients
            filteredRecipes = filteredRecipes.filter { recipe in
                for excluded in excludedIngredients {
                    if recipe.ingredientTags.contains(excluded) {
                        return false
                    }
                }
                return true
            }
            
            // Filter by excluded allergens
            filteredRecipes = filteredRecipes.filter { recipe in
                return !recipe.containsAllergens(excludedAllergens)
            }
            
            // Filter by specified ingredients if not random mode
            let hasSpecificIngredients = !isRandom && specifiedIngredients?.isEmpty == false
            if hasSpecificIngredients, let ingredients = specifiedIngredients {
                print("📱 RecipeService: Filtering for specific ingredients: \(ingredients)")
                let allMatch = filteredRecipes.filter { recipe in
                    ingredients.allSatisfy { ingredient in
                        recipe.ingredientTags.contains(ingredient)
                    }
                }
                
                print("📱 RecipeService: Recipes matching all specified ingredients: \(allMatch.count)")
                
                if !allMatch.isEmpty {
                    filteredRecipes = allMatch
                } else {
                    // If no recipes match the specified ingredients, show "no recipe found"
                    // Don't fall back to ignoring ingredient requirements
                    print("📱 RecipeService: No recipes found with specified ingredients (\(ingredients.joined(separator: ", "))) - showing 'no results found'")
                    completion(nil)
                    return
                }
            }
            
            // If no recipes match the criteria after all filtering, fall back to budget-only filtering
            // But only if we didn't have specific ingredient requirements
            if filteredRecipes.isEmpty && !hasSpecificIngredients {
                print("📱 RecipeService: No recipes match criteria, falling back to budget-only filtering")
                // Apply only budget filter as final fallback to avoid showing inappropriate results
                var budgetFilteredRecipes = allFallbackRecipes
                
                // IMPORTANT: Still apply cuisine filter even in fallback
                if let cuisine = cuisine {
                    if cuisine == "すべて" {
                        // "すべて" means show all cuisines, so no filtering needed
                    } else if cuisine == "その他" {
                        // "その他" means exclude the main cuisine categories (和食、洋食、中華、イタリアン、韓国、フレンチ)
                        let mainCuisines = ["和食", "洋食", "中華", "イタリアン", "韓国", "フレンチ"]
                        budgetFilteredRecipes = budgetFilteredRecipes.filter { !mainCuisines.contains($0.cuisine) }
                        print("📱 RecipeService: Applied その他 filter in fallback - remaining: \(budgetFilteredRecipes.count)")
                    } else {
                        budgetFilteredRecipes = budgetFilteredRecipes.filter { $0.cuisine == cuisine }
                        print("📱 RecipeService: Applied specific cuisine filter in fallback - remaining: \(budgetFilteredRecipes.count)")
                    }
                }
                
                // Apply budget filtering even in fallback (handle both formats correctly)
                switch budget {
                case .under500:
                    budgetFilteredRecipes = budgetFilteredRecipes.filter { 
                        let perServingCost = $0.scaledCost(for: 1)
                        return perServingCost <= 500
                    }
                case .between500_1000:
                    budgetFilteredRecipes = budgetFilteredRecipes.filter { 
                        let perServingCost = $0.scaledCost(for: 1)
                        return perServingCost > 500 && perServingCost <= 1000 
                    }
                case .between1000_1500:
                    budgetFilteredRecipes = budgetFilteredRecipes.filter { 
                        let perServingCost = $0.scaledCost(for: 1)
                        return perServingCost > 1000 && perServingCost <= 1500 
                    }
                case .custom(let min, let max):
                    budgetFilteredRecipes = budgetFilteredRecipes.filter { 
                        let perServingCost = $0.scaledCost(for: 1)
                        return (min <= 0 || perServingCost >= min) && perServingCost <= max
                    }
                case .noLimit:
                    break
                }
                
                print("📱 RecipeService: Budget fallback has \(budgetFilteredRecipes.count) recipes")
                
                // If budget-filtered recipes exist, use them; otherwise return nil to show "no results"
                filteredRecipes = budgetFilteredRecipes
            }
            
            // If no recipes match the criteria after filtering, return nil
            guard !filteredRecipes.isEmpty else {
                print("📱 RecipeService: No recipes match the current criteria - showing 'no results found'")
                completion(nil)
                return
            }
            
            print("📱 RecipeService: Final filtered recipes count: \(filteredRecipes.count)")
            let randomIndex = Int.random(in: 0..<filteredRecipes.count)
            let selectedRecipe = filteredRecipes[randomIndex]
            print("📱 RecipeService: Selected recipe: '\(selectedRecipe.title)' with cuisine: '\(selectedRecipe.cuisine)'")
            completion(selectedRecipe)
        }
    }
    
    private func createFallbackJapaneseRecipes() -> [Recipe] {
        // Always load from JSON file instead of hardcoded fallback
        print("📱 RecipeService: Loading recipes from JSON file")
        let jsonRecipes = LocalDataLoader.shared.loadRecipesFromJSON()
        
        if !jsonRecipes.isEmpty {
            print("📱 RecipeService: Successfully loaded \(jsonRecipes.count) recipes from JSON")
            return jsonRecipes
        }
        
        // If JSON loading fails, log error and return empty array
        print("❌ RecipeService: Failed to load recipes from JSON file, returning empty array")
        return []
    }
}

// Helper extension for chunking arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 