import Foundation
import FirebaseFirestore

class EatingOutMealService: ObservableObject {
    static let shared = EatingOutMealService()
    
    private let db = Firestore.firestore()
    private let dbQueue = DispatchQueue(label: "com.meshisele.eatingoutmealservice.db", qos: .userInitiated)
    
    private init() {}
    
    func fetchRandomEatingOutMeal(
        dietFilter: String,
        cuisine: String?,
        budget: BudgetOption,
        excludedIngredients: [String],
        excludedAllergens: [String],
        completion: @escaping (EatingOutMeal?) -> Void
    ) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var query: Query = self.db.collection("eatingOutMeals")
                .whereField("dietTags", arrayContains: dietFilter)
            
            // Budget constraint
            switch budget {
            case .under500:
                query = query.whereField("estimatedBudget", isLessThanOrEqualTo: 500)
            case .between500_1000:
                query = query
                    .whereField("estimatedBudget", isGreaterThan: 500)
                    .whereField("estimatedBudget", isLessThanOrEqualTo: 1000)
            case .between1000_1500:
                query = query
                    .whereField("estimatedBudget", isGreaterThan: 1000)
                    .whereField("estimatedBudget", isLessThanOrEqualTo: 1500)
            case .custom(let min, let max):
                if min > 0 {
                    query = query.whereField("estimatedBudget", isGreaterThanOrEqualTo: min)
                }
                query = query.whereField("estimatedBudget", isLessThanOrEqualTo: max)
            case .noLimit:
                break
            }
            
            // Cuisine filter - convert display name to raw value for eating out meals
            if let cuisine = cuisine {
                if cuisine == "すべて" {
                    // "すべて" means show all cuisines, so no filtering needed
                } else if cuisine == "その他" {
                    // "その他" means exclude the main cuisine categories (和食、洋食、中華、イタリアン、韓国、フレンチ)
                    let mainCuisines = ["washoku", "yoshoku", "chuka", "italian", "korean", "french"]
                    query = query.whereField("cuisine", notIn: mainCuisines)
                } else {
                let cuisineRawValue = CuisineOption.allCases.first { $0.displayName == cuisine }?.rawValue ?? cuisine
                query = query.whereField("cuisine", isEqualTo: cuisineRawValue)
                }
            }
            
            // Add timeout mechanism
            let timeoutWorkItem = DispatchWorkItem { [weak self] in
                print("⚠️ EatingOutMealService: Query timeout, using fallback meals")
                self?.getFallbackEatingOutMeal(dietFilter: dietFilter, cuisine: cuisine, budget: budget, excludedIngredients: excludedIngredients, excludedAllergens: excludedAllergens, completion: completion)
            }
            
            // Set 6 second timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: timeoutWorkItem)
            
            query.getDocuments { snapshot, error in
                // Cancel timeout if request completes
                timeoutWorkItem.cancel()
                
                DispatchQueue.main.async {
                    if let error = error {
                        print("🔥 EatingOutMealService: Firebase error - \(error.localizedDescription)")
                        self.getFallbackEatingOutMeal(dietFilter: dietFilter, cuisine: cuisine, budget: budget, excludedIngredients: excludedIngredients, excludedAllergens: excludedAllergens, completion: completion)
                        return
                    }
                    
                    if let docs = snapshot?.documents, !docs.isEmpty {
                        let afterExclusion = docs.compactMap { doc -> EatingOutMeal? in
                            let data = doc.data()
                            let tags = data["dietTags"] as? [String] ?? []
                            let name = data["name"] as? String ?? ""
                            
                            // Check if meal name or tags contain excluded ingredients
                            for excluded in excludedIngredients {
                                if name.lowercased().contains(excluded.lowercased()) ||
                                   tags.contains(where: { $0.lowercased().contains(excluded.lowercased()) }) {
                                    return nil
                                }
                            }
                            
                            let meal = EatingOutMeal(data: data, id: doc.documentID)
                            
                            // Check excluded allergens
                            if meal.containsAllergens(excludedAllergens) {
                                return nil
                            }
                            
                            return meal
                        }
                        
                        guard !afterExclusion.isEmpty else {
                            self.getFallbackEatingOutMeal(dietFilter: dietFilter, cuisine: cuisine, budget: budget, excludedIngredients: excludedIngredients, excludedAllergens: excludedAllergens, completion: completion)
                            return
                        }
                        
                        let randomIndex = Int.random(in: 0..<afterExclusion.count)
                        completion(afterExclusion[randomIndex])
                    } else {
                        print("📱 EatingOutMealService: No Firebase results found, using fallback meals")
                        self.getFallbackEatingOutMeal(dietFilter: dietFilter, cuisine: cuisine, budget: budget, excludedIngredients: excludedIngredients, excludedAllergens: excludedAllergens, completion: completion)
                    }
                }
            }
        }
    }
    
    private func getFallbackEatingOutMeal(
        dietFilter: String,
        cuisine: String?,
        budget: BudgetOption,
        excludedIngredients: [String],
        excludedAllergens: [String],
        completion: @escaping (EatingOutMeal?) -> Void
    ) {
        print("🍽️ EatingOutMealService: Using fallback eating out meals")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let fallbackMeals = self.createFallbackEatingOutMeals()
            
            // Filter by criteria
            var filtered = fallbackMeals
            
            // Filter by cuisine if specified - convert display name to raw value
            if let cuisine = cuisine {
                if cuisine == "すべて" {
                    // "すべて" means show all cuisines, so no filtering needed
                } else if cuisine == "その他" {
                    // "その他" means exclude the main cuisine categories (和食、洋食、中華、イタリアン、韓国、フレンチ)
                    let mainCuisines = ["washoku", "yoshoku", "chuka", "italian", "korean", "french"]
                    filtered = filtered.filter { !mainCuisines.contains($0.cuisine) }
                } else {
                let cuisineRawValue = CuisineOption.allCases.first { $0.displayName == cuisine }?.rawValue ?? cuisine
                filtered = filtered.filter { $0.cuisine == cuisineRawValue }
                }
            }
            
            // Filter by budget
            switch budget {
            case .under500:
                filtered = filtered.filter { $0.estimatedBudget <= 500 }
            case .between500_1000:
                filtered = filtered.filter { $0.estimatedBudget > 500 && $0.estimatedBudget <= 1000 }
            case .between1000_1500:
                filtered = filtered.filter { $0.estimatedBudget > 1000 && $0.estimatedBudget <= 1500 }
            case .custom(let min, let max):
                filtered = filtered.filter { $0.estimatedBudget >= min && $0.estimatedBudget <= max }
            case .noLimit:
                break
            }
            
            // Filter by excluded ingredients
            filtered = filtered.filter { meal in
                for excluded in excludedIngredients {
                    if meal.name.lowercased().contains(excluded.lowercased()) ||
                       meal.dietTags.contains(where: { $0.lowercased().contains(excluded.lowercased()) }) {
                        return false
                    }
                }
                return true
            }
            
            // Filter by excluded allergens
            filtered = filtered.filter { meal in
                return !meal.containsAllergens(excludedAllergens)
            }
            
            if filtered.isEmpty {
                filtered = fallbackMeals // Fallback to all meals if no matches
            }
            
            let randomIndex = Int.random(in: 0..<filtered.count)
            completion(filtered[randomIndex])
        }
    }
    
    private func createFallbackEatingOutMeals() -> [EatingOutMeal] {
        // First try to load from JSON file
        let jsonMeals = LocalDataLoader.shared.loadEatingOutMealsFromJSON()
        if !jsonMeals.isEmpty {
            return jsonMeals
        }
        
        // If JSON loading fails, use hardcoded fallback
        print("📱 EatingOutMealService: Using hardcoded fallback meals")
        return [
            EatingOutMeal(
                name: "ラーメン",
                description: "醤油、味噌、豚骨など様々な味が楽しめる日本の代表的な麺料理",
                cuisine: "washoku",
                dietTags: ["all", "meat"],
                estimatedBudget: 800,
                popularityCount: 156,
                emoji: "🍜",
                searchKeywords: ["ラーメン", "麺", "ramen"]
            ),
            EatingOutMeal(
                name: "寿司",
                description: "新鮮な魚介類を使った日本の伝統料理",
                cuisine: "washoku",
                dietTags: ["all", "healthy"],
                estimatedBudget: 2000,
                popularityCount: 89,
                emoji: "🍣",
                searchKeywords: ["寿司", "すし", "sushi"]
            ),
            EatingOutMeal(
                name: "ハンバーガー",
                description: "ジューシーなパティとフレッシュな野菜のアメリカ料理",
                cuisine: "yoshoku",
                dietTags: ["all", "meat"],
                estimatedBudget: 1200,
                popularityCount: 134,
                emoji: "🍔",
                searchKeywords: ["ハンバーガー", "burger", "バーガー"]
            ),
            EatingOutMeal(
                name: "パスタ",
                description: "豊富なソースとトッピングが選べるイタリア料理",
                cuisine: "italian",
                dietTags: ["all", "vegetarian"],
                estimatedBudget: 1300,
                popularityCount: 98,
                emoji: "🍝",
                searchKeywords: ["パスタ", "pasta", "イタリアン"]
            ),
            EatingOutMeal(
                name: "カレー",
                description: "スパイシーで温かいライス料理",
                cuisine: "other",
                dietTags: ["all", "vegetarian"],
                estimatedBudget: 900,
                popularityCount: 112,
                emoji: "🍛",
                searchKeywords: ["カレー", "curry", "カレーライス"]
            ),
            EatingOutMeal(
                name: "中華料理",
                description: "炒め物や点心など多彩な中国料理",
                cuisine: "chuka",
                dietTags: ["all", "meat"],
                estimatedBudget: 1100,
                popularityCount: 87,
                emoji: "🥟",
                searchKeywords: ["中華", "chinese", "炒飯", "餃子"]
            ),
            EatingOutMeal(
                name: "焼肉",
                description: "ジューシーなお肉を焼いて楽しむ料理",
                cuisine: "washoku",
                dietTags: ["all", "meat"],
                estimatedBudget: 2500,
                popularityCount: 76,
                emoji: "🥩",
                searchKeywords: ["焼肉", "yakiniku", "bbq"]
            ),
            EatingOutMeal(
                name: "サラダボウル",
                description: "新鮮な野菜とヘルシーなトッピングの軽食",
                cuisine: "yoshoku",
                dietTags: ["healthy", "vegetarian"],
                estimatedBudget: 800,
                popularityCount: 65,
                emoji: "🥗",
                searchKeywords: ["サラダ", "salad", "ヘルシー"]
            ),
            EatingOutMeal(
                name: "うどん",
                description: "もちもちした太麺が特徴の日本の麺料理",
                cuisine: "washoku",
                dietTags: ["all", "vegetarian"],
                estimatedBudget: 600,
                popularityCount: 94,
                emoji: "🍲",
                searchKeywords: ["うどん", "udon", "麺"]
            ),
            EatingOutMeal(
                name: "ピザ",
                description: "チーズとトッピングがたっぷりのイタリア料理",
                cuisine: "italian",
                dietTags: ["all", "vegetarian"],
                estimatedBudget: 1500,
                popularityCount: 103,
                emoji: "🍕",
                searchKeywords: ["ピザ", "pizza", "イタリアン"]
            ),
            EatingOutMeal(
                name: "韓国料理",
                description: "辛くて美味しいキムチやビビンバなどの韓国料理",
                cuisine: "korean",
                dietTags: ["all", "meat"],
                estimatedBudget: 1200,
                popularityCount: 89,
                emoji: "🇰🇷",
                searchKeywords: ["韓国料理", "korean", "キムチ", "ビビンバ"]
            ),
            EatingOutMeal(
                name: "フレンチ",
                description: "洗練されたフランス料理の数々",
                cuisine: "french",
                dietTags: ["all", "meat"],
                estimatedBudget: 3000,
                popularityCount: 67,
                emoji: "🇫🇷",
                searchKeywords: ["フレンチ", "french", "フランス料理"]
            )
        ]
    }
} 