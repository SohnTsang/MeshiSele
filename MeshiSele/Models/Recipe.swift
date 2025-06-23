import Foundation
import FirebaseFirestore

struct Recipe: Codable, Identifiable {
    let id: String
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let totalTime: Int // minutes
    let servings: Int
    let dietTags: [String]
    let ingredientTags: [String]
    let estimatedCost: Int // yen
    let nutrition: Nutrition
    let allergens: Allergens
    let imageURL: String?
    let cuisine: String
    let createdAt: Date
    let updatedAt: Date
    let popularityCount: Int // how many people chose this recipe
    
    struct Nutrition: Codable {
        // Basic macronutrients (1人前あたり)
        let calories: Int // kcal
        let protein: Double // g
        let fat: Double // g
        let carbs: Double // g (糖質 - carbohydrates)
        let fiber: Double // g (食物繊維)
        let sodium: Int // mg (ナトリウム)
        let cholesterol: Int // mg (コレステロール)
        let saturatedFat: Double // g (飽和脂肪酸)
        
        // Initialize with default values for backward compatibility
        init(calories: Int = 0, protein: Double = 0.0, fat: Double = 0.0, carbs: Double = 0.0, 
             fiber: Double = 0.0, sodium: Int = 0, cholesterol: Int = 0, saturatedFat: Double = 0.0) {
            self.calories = calories
            self.protein = protein
            self.fat = fat
            self.carbs = carbs
            self.fiber = fiber
            self.sodium = sodium
            self.cholesterol = cholesterol
            self.saturatedFat = saturatedFat
        }
    }
    
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
    
    init(data: [String: Any], id: String? = nil) {
        self.id = id ?? data["id"] as? String ?? UUID().uuidString
        self.title = data["title"] as? String ?? "Unknown Recipe"
        self.ingredients = data["ingredients"] as? [String] ?? []
        self.instructions = data["instructions"] as? [String] ?? []
        self.totalTime = data["totalTime"] as? Int ?? 0
        self.servings = max(1, data["servings"] as? Int ?? 1) // Ensure servings is at least 1
        self.dietTags = data["dietTags"] as? [String] ?? ["all"]
        self.ingredientTags = data["ingredientTags"] as? [String] ?? []
        self.estimatedCost = max(0, data["estimatedCost"] as? Int ?? 0) // Ensure cost is non-negative
        self.imageURL = data["imageURL"] as? String
        self.cuisine = data["cuisine"] as? String ?? "和食"
        self.popularityCount = max(0, data["popularityCount"] as? Int ?? 0) // Ensure popularity is non-negative
        
        // Enhanced nutrition parsing with better error handling
        if let nutritionData = data["nutrition"] as? [String: Any] {
            self.nutrition = Nutrition(
                calories: max(0, nutritionData["calories"] as? Int ?? 0),
                protein: max(0.0, nutritionData["protein"] as? Double ?? 0.0),
                fat: max(0.0, nutritionData["fat"] as? Double ?? 0.0),
                carbs: max(0.0, nutritionData["carbs"] as? Double ?? 0.0),
                fiber: max(0.0, nutritionData["fiber"] as? Double ?? 0.0),
                sodium: max(0, nutritionData["sodium"] as? Int ?? 0),
                cholesterol: max(0, nutritionData["cholesterol"] as? Int ?? 0),
                saturatedFat: max(0.0, nutritionData["saturatedFat"] as? Double ?? 0.0)
            )
        } else {
            print("⚠️ Recipe \(self.id): No nutrition data found, using defaults")
            self.nutrition = Nutrition()
        }
        
        // Allergen parsing with error handling
        if let allergenData = data["allergens"] as? [String: Any] {
            self.allergens = Allergens(
                mandatory: allergenData["mandatory"] as? [String] ?? [],
                recommended: allergenData["recommended"] as? [String] ?? []
            )
        } else {
            print("⚠️ Recipe \(self.id): No allergen data found, using defaults")
            self.allergens = Allergens()
        }
        
        // Dates with better error handling
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        if let timestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = timestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
        
        // Validation logging for debugging
        if self.title.isEmpty {
            print("⚠️ Recipe \(self.id): Empty title")
        }
        if self.ingredients.isEmpty {
            print("⚠️ Recipe \(self.id): No ingredients")
        }
        if self.instructions.isEmpty {
            print("⚠️ Recipe \(self.id): No instructions")
        }
    }
    
    // Convert to dictionary for Firestore
    var dictionary: [String: Any] {
        return [
            "title": title,
            "ingredients": ingredients,
            "instructions": instructions,
            "totalTime": totalTime,
            "servings": servings,
            "dietTags": dietTags,
            "ingredientTags": ingredientTags,
            "estimatedCost": estimatedCost,
            "nutrition": [
                "calories": nutrition.calories,
                "protein": nutrition.protein,
                "fat": nutrition.fat,
                "carbs": nutrition.carbs,
                "fiber": nutrition.fiber,
                "sodium": nutrition.sodium,
                "cholesterol": nutrition.cholesterol,
                "saturatedFat": nutrition.saturatedFat
            ],
            "allergens": [
                "mandatory": allergens.mandatory,
                "recommended": allergens.recommended
            ],
            "imageURL": imageURL ?? "",
            "cuisine": cuisine,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "popularityCount": popularityCount
        ]
    }
    
    // Scale ingredients for different serving sizes
    func scaledIngredients(for servings: Int) -> [String] {
        let scaleFactor = Double(servings) / Double(self.servings)
        return ingredients.map { ingredient in
            // Simple scaling - in a real app you'd want more sophisticated parsing
            if scaleFactor == 1.0 {
                return ingredient
            }
            return ingredient + " (×\(String(format: "%.1f", scaleFactor)))"
        }
    }
    
    // Scale nutrition for different serving sizes
    func scaledNutrition(for servings: Int) -> Nutrition {
        let scaleFactor = Double(servings) / Double(self.servings)
        
        // Ensure scaleFactor is valid
        guard scaleFactor > 0 && scaleFactor.isFinite else {
            print("⚠️ Invalid scale factor: \(scaleFactor), using original nutrition")
            return nutrition
        }
        
        return Nutrition(
            calories: Int(Double(nutrition.calories) * scaleFactor),
            protein: nutrition.protein * scaleFactor,
            fat: nutrition.fat * scaleFactor,
            carbs: nutrition.carbs * scaleFactor,
            fiber: nutrition.fiber * scaleFactor,
            sodium: Int(Double(nutrition.sodium) * scaleFactor),
            cholesterol: Int(Double(nutrition.cholesterol) * scaleFactor),
            saturatedFat: nutrition.saturatedFat * scaleFactor
        )
    }
    
    // Calculate scaled cost based on person count
    func scaledCost(for servings: Int) -> Int {
        let scaleFactor = Double(servings) / Double(self.servings)
        return Int(Double(estimatedCost) * scaleFactor)
    }
    

} 