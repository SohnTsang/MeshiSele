import Foundation

class LocalDataLoader {
    static let shared = LocalDataLoader()
    
    private init() {}
    
    func loadRecipesFromJSON() -> [Recipe] {
        guard let path = Bundle.main.path(forResource: "recipes", ofType: "json"),
              let data = NSData(contentsOfFile: path) else {
            return []
        }
        
        do {
            let jsonResult = try JSONSerialization.jsonObject(with: data as Data, options: .mutableLeaves)
            
            if let jsonResult = jsonResult as? [String: Any],
               let recipesArray = jsonResult["recipes"] as? [[String: Any]] {
                
                let recipes = recipesArray.compactMap { recipeData in
                    return Recipe(data: recipeData, id: recipeData["id"] as? String ?? UUID().uuidString)
                }
                
                return recipes
            }
        } catch {
            // Error parsing recipes JSON - handle silently
        }
        
        return []
    }
    
    func loadEatingOutMealsFromJSON() -> [EatingOutMeal] {
        guard let path = Bundle.main.path(forResource: "eating_out_meals", ofType: "json"),
              let data = NSData(contentsOfFile: path) else {
            return []
        }
        
        do {
            let jsonResult = try JSONSerialization.jsonObject(with: data as Data, options: .mutableLeaves)
            
            if let jsonResult = jsonResult as? [String: Any],
               let mealsArray = jsonResult["eatingOutMeals"] as? [[String: Any]] {
                
                let meals = mealsArray.compactMap { mealData in
                    return EatingOutMeal(data: mealData, id: mealData["id"] as? String ?? UUID().uuidString)
                }
                
                return meals
            }
        } catch {
            // Error parsing JSON - handle silently
        }
        
        return []
    }
} 