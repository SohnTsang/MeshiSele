import Foundation

enum MealResultType: String, Codable {
    case recipe = "recipe"
    case restaurant = "restaurant"
    case eatingOutMeal = "eatingOutMeal"
}

struct MealResult: Codable, Identifiable {
    let id: String
    let type: MealResultType
    let timestamp: Date
    
    // Recipe data (if type == .recipe)
    var recipe: Recipe?
    
    // Restaurant data (if type == .restaurant)
    var restaurant: Restaurant?
    
    // Eating out meal data (if type == .eatingOutMeal)
    var eatingOutMeal: EatingOutMeal?
    
    init(type: MealResultType, id: String, data: Any) {
        self.id = id
        self.type = type
        self.timestamp = Date()
        
        switch type {
        case .recipe:
            self.recipe = data as? Recipe
            self.restaurant = nil
            self.eatingOutMeal = nil
        case .restaurant:
            self.restaurant = data as? Restaurant
            self.recipe = nil
            self.eatingOutMeal = nil
        case .eatingOutMeal:
            self.eatingOutMeal = data as? EatingOutMeal
            self.recipe = nil
            self.restaurant = nil
        }
    }
    
    var displayName: String {
        switch type {
        case .recipe:
            return recipe?.title ?? "Unknown Recipe"
        case .restaurant:
            return restaurant?.name ?? "Unknown Restaurant"
        case .eatingOutMeal:
            return eatingOutMeal?.name ?? "Unknown Meal"
        }
    }
    
    var displayImage: String? {
        switch type {
        case .recipe:
            return recipe?.imageURL
        case .restaurant:
            return restaurant?.imageURL
        case .eatingOutMeal:
            return nil // EatingOutMeal uses emoji instead of image URL
        }
    }
} 