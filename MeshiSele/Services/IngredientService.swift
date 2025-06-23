import Foundation
import FirebaseFirestore

class IngredientService: ObservableObject {
    static let shared = IngredientService()
    
    @Published private(set) var availableIngredients: [String] = []
    @Published private(set) var isLoading = false
    
    private let db = Firestore.firestore()
    private let localDataLoader = LocalDataLoader.shared
    
    // Performance optimization: cache search results
    private var searchCache: [String: [String]] = [:]
    private let maxCacheSize = 100
    
    private init() {
        loadAvailableIngredients()
    }
    
    private func loadAvailableIngredients() {
        isLoading = true
        print("🥕 IngredientService: Starting to load ingredients from Firebase...")
        
        // First try Firebase, fallback to local if needed
        loadIngredientsFromFirebase { [weak self] success in
            if !success {
                print("🥕 IngredientService: Firebase failed, falling back to local JSON")
                self?.loadIngredientsFromLocal()
            }
        }
    }
    
    private func loadIngredientsFromFirebase(completion: @escaping (Bool) -> Void) {
        db.collection("recipes").getDocuments { [weak self] snapshot, error in
            guard let self = self else {
                completion(false)
                return
            }
            
            if let error = error {
                print("❌ IngredientService: Firebase error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("❌ IngredientService: No Firebase documents found")
                completion(false)
                return
            }
            
            print("🥕 IngredientService: Found \(documents.count) recipes in Firebase")
            
            // Extract all ingredient tags from all recipes
            var allIngredients: [String] = []
            for document in documents {
                if let ingredientTags = document.data()["ingredientTags"] as? [String] {
                    allIngredients.append(contentsOf: ingredientTags)
                }
            }
            
            let uniqueIngredients = Array(Set(allIngredients)).sorted()
            
            DispatchQueue.main.async {
                self.availableIngredients = uniqueIngredients
                self.isLoading = false
                print("🥕 IngredientService: Successfully loaded \(uniqueIngredients.count) ingredients from Firebase")
                print("🥕 First 10 ingredients: \(Array(uniqueIngredients.prefix(10)))")
                completion(true)
            }
        }
    }
    
    private func loadIngredientsFromLocal() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let recipes = self.localDataLoader.loadRecipesFromJSON()
            let allIngredients = recipes.flatMap { $0.ingredientTags }
            let uniqueIngredients = Array(Set(allIngredients)).sorted()
            
            DispatchQueue.main.async {
                self.availableIngredients = uniqueIngredients
                self.isLoading = false
                print("🥕 IngredientService: Loaded \(uniqueIngredients.count) ingredients from local JSON")
                print("🥕 First 10 ingredients: \(Array(uniqueIngredients.prefix(10)))")
            }
        }
    }
    
    func searchIngredients(query: String) -> [String] {
        guard !query.isEmpty else { return [] }
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        // Check cache first
        if let cachedResults = searchCache[trimmedQuery] {
            return cachedResults
        }
        
        let normalizedQuery = normalizeJapaneseText(trimmedQuery)
        
        let results = availableIngredients.compactMap { ingredient -> (String, Int)? in
            let score = calculateMatchScore(query: trimmedQuery, normalizedQuery: normalizedQuery, ingredient: ingredient)
            return score > 0 ? (ingredient, score) : nil
        }
        .sorted { $0.1 > $1.1 } // Sort by score descending
        .prefix(10)
        .map { $0.0 }
        
        let finalResults = Array(results)
        
        // Cache results (with size limit)
        if searchCache.count >= maxCacheSize {
            // Remove oldest entries (simple FIFO)
            let keysToRemove = Array(searchCache.keys.prefix(10))
            keysToRemove.forEach { searchCache.removeValue(forKey: $0) }
        }
        searchCache[trimmedQuery] = finalResults
        
        return finalResults
    }
    
    private func calculateMatchScore(query: String, normalizedQuery: String, ingredient: String) -> Int {
        var score = 0
        let normalizedIngredient = normalizeJapaneseText(ingredient)
        
        // Fast early checks with higher scores for better matches
        
        // 1. Exact match (highest score)
        if ingredient == query {
            return 1000
        }
        
        // 2. Starts with query (very high score)
        if ingredient.hasPrefix(query) {
            score += 800
        }
        
        // 3. Direct substring match
        if ingredient.contains(query) {
            score += 600
        }
        
        // 4. Normalized hiragana match (ingredient contains query)
        if normalizedIngredient.contains(normalizedQuery) {
            score += 400
        }
        
        // 5. Common ingredient mappings (medium score)
        if checkCommonIngredientMappings(query: query, ingredient: ingredient) {
            score += 300
        }
        
        // 6. Katakana variations (lower score due to computational cost)
        if score == 0 && checkJapaneseVariations(query: normalizedQuery, ingredient: normalizedIngredient) {
            score += 200
        }
        
        // Remove the problematic bidirectional matching
        // Only return score if we found a legitimate match above
        return score
    }
    
    func isValidIngredient(_ ingredient: String) -> Bool {
        let trimmedIngredient = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInput = normalizeJapaneseText(trimmedIngredient)
        
        // Check exact match first
        if availableIngredients.contains(trimmedIngredient) {
            return true
        }
        
        // Check normalized variations
        return availableIngredients.contains { availableIngredient in
            let normalizedAvailable = normalizeJapaneseText(availableIngredient)
            return normalizedAvailable == normalizedInput ||
                   checkJapaneseVariations(query: normalizedInput, ingredient: normalizedAvailable)
        }
    }
    
    private func normalizeJapaneseText(_ text: String) -> String {
        // Convert to hiragana for comparison
        return text.applyingTransform(.fullwidthToHalfwidth, reverse: false)?.applyingTransform(.hiraganaToKatakana, reverse: true) ?? text
    }
    
    private func checkJapaneseVariations(query: String, ingredient: String) -> Bool {
        // Convert query to katakana and check if ingredient contains it
        let queryAsKatakana = query.applyingTransform(.hiraganaToKatakana, reverse: false) ?? query
        
        // Only check if ingredient contains the query (not bidirectional)
        return ingredient.contains(queryAsKatakana)
    }
    
    // Pre-computed mappings for better performance
    private static let ingredientMappings: [String: [String]] = [
        "鶏肉": ["とりにく", "とり", "チキン", "鶏"],
        "豚肉": ["ぶたにく", "ぶた", "ポーク", "豚"],
        "牛肉": ["ぎゅうにく", "うし", "ビーフ", "牛"],
        "玉ねぎ": ["たまねぎ", "オニオン", "玉葱"],
        "人参": ["にんじん", "ニンジン", "キャロット"],
        "じゃがいも": ["じゃが芋", "ジャガイモ", "ポテト"],
        "キャベツ": ["きゃべつ", "キャベジ"],
        "卵": ["たまご", "エッグ", "玉子"],
        "海老": ["えび", "エビ", "シュリンプ"],
        "鮭": ["さけ", "サケ", "サーモン"],
        "豆腐": ["とうふ", "トウフ"],
        "ご飯": ["ごはん", "米", "こめ", "ライス"],
        "にんにく": ["ニンニク", "ガーリック"],
        "生姜": ["しょうが", "ショウガ", "ジンジャー"],
        "ねぎ": ["ネギ", "葱"],
        "もやし": ["モヤシ"],
        "きのこ": ["キノコ", "茸"],
        "トマト": ["とまと", "tomato"],
        "レタス": ["れたす"],
        "きゅうり": ["キュウリ", "胡瓜"]
    ]
    
    private func checkCommonIngredientMappings(query: String, ingredient: String) -> Bool {
        // Direct mapping check - does ingredient have variations that match query?
        if let variations = Self.ingredientMappings[ingredient] {
            return variations.contains { variation in
                variation.contains(query) || variation == query
            }
        }
        
        // Reverse mapping check - does query match any kanji ingredient?
        for (kanji, variations) in Self.ingredientMappings {
            if kanji == ingredient {
                // Check if query matches any variation of this ingredient
                return variations.contains { variation in
                    query.contains(variation) || query == variation
                }
            }
        }
        
        return false
    }
    

} 