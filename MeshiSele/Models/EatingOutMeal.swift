import Foundation

struct EatingOutMeal: Codable, Identifiable {
    let id: String
    let name: String // e.g., "ラーメン", "寿司", "ハンバーガー"
    let description: String // Brief description of the meal
    let cuisine: String // Maps to restaurant search categories
    let dietTags: [String] // For filtering (healthy, vegetarian, etc.)
    let estimatedBudget: Int // Expected cost per person
    let popularityCount: Int // How many times it was chosen
    let emoji: String // Visual representation
    let searchKeywords: [String] // Keywords for restaurant search
    let allergens: Allergens
    
    struct Allergens: Codable {
        let mandatory: [String] // 特定原材料 (8 items)
        let recommended: [String] // 特定原材料に準ずるもの (20 items)
        
        init(mandatory: [String] = [], recommended: [String] = []) {
            self.mandatory = mandatory
            self.recommended = recommended
        }
    }
    
    func containsAllergens(_ excludedAllergens: [String]) -> Bool {
        for allergen in excludedAllergens {
            if allergens.mandatory.contains(allergen) || allergens.recommended.contains(allergen) {
                return true
            }
        }
        return false
    }
    
    init(
        id: String? = nil,
        name: String,
        description: String,
        cuisine: String,
        dietTags: [String] = [],
        estimatedBudget: Int,
        popularityCount: Int = 0,
        emoji: String,
        searchKeywords: [String] = [],
        allergens: Allergens = Allergens()
    ) {
        self.id = id ?? UUID().uuidString
        self.name = name
        self.description = description
        self.cuisine = cuisine
        self.dietTags = dietTags
        self.estimatedBudget = estimatedBudget
        self.popularityCount = popularityCount
        self.emoji = emoji
        self.searchKeywords = searchKeywords.isEmpty ? [name] : searchKeywords
        self.allergens = allergens
    }
    
    init(data: [String: Any], id: String) {
        self.id = id
        self.name = data["name"] as? String ?? ""
        self.description = data["description"] as? String ?? ""
        self.cuisine = data["cuisine"] as? String ?? ""
        self.dietTags = data["dietTags"] as? [String] ?? []
        self.estimatedBudget = data["estimatedBudget"] as? Int ?? 1000
        self.popularityCount = data["popularityCount"] as? Int ?? 0
        self.emoji = data["emoji"] as? String ?? "🍽️"
        self.searchKeywords = data["searchKeywords"] as? [String] ?? [name]
        
        // Allergen parsing with error handling
        if let allergenData = data["allergens"] as? [String: Any] {
            self.allergens = Allergens(
                mandatory: allergenData["mandatory"] as? [String] ?? [],
                recommended: allergenData["recommended"] as? [String] ?? []
            )
        } else {
            print("⚠️ EatingOutMeal \(self.id): No allergen data found, using defaults")
            self.allergens = Allergens()
        }
    }
    
    var dictionary: [String: Any] {
        return [
            "name": name,
            "description": description,
            "cuisine": cuisine,
            "dietTags": dietTags,
            "estimatedBudget": estimatedBudget,
            "popularityCount": popularityCount,
            "emoji": emoji,
            "searchKeywords": searchKeywords,
            "allergens": [
                "mandatory": allergens.mandatory,
                "recommended": allergens.recommended
            ]
        ]
    }
    

} 