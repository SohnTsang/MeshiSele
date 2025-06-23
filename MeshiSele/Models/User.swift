import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    let id: String
    var displayName: String
    var email: String
    let createdAt: Date
    var defaultPreferences: DefaultPreferences
    
    struct DefaultPreferences: Codable {
        // Cook mode settings
        var cookDietFilter: String?
        var cookCuisine: String?
        var cookIsSurprise: Bool
        var cookSpecifiedIngredients: [String]
        var cookExcludedIngredients: [String]
        var cookExcludedAllergens: [String]
        var cookServingsCount: Int
        var cookBudgetRange: String
        var cookCookTimeConstraint: String
        
        // Eat out mode settings
        var eatOutDietFilter: String?
        var eatOutCuisine: String?
        var eatOutIsSurprise: Bool
        var eatOutSpecifiedIngredients: [String]
        var eatOutExcludedIngredients: [String]
        var eatOutExcludedAllergens: [String]
        var eatOutBudgetRange: String
        
        // Legacy properties for backward compatibility
        var mealMode: String? { return nil }
        var dietFilter: String? { return cookDietFilter }
        var cuisine: String? { return cookCuisine }
        var isSurprise: Bool { return cookIsSurprise }
        var specifiedIngredients: [String] { return cookSpecifiedIngredients }
        var excludedIngredients: [String] { return cookExcludedIngredients }
        var excludedAllergens: [String] { return cookExcludedAllergens }
        var servingsCount: Int { return cookServingsCount }
        var budgetRange: String { return cookBudgetRange }
        var cookTimeConstraint: String { return cookCookTimeConstraint }
        var pushNotificationsEnabled: Bool { return false }
        
        init() {
            // Cook mode defaults
            self.cookDietFilter = "all"
            self.cookCuisine = "all"
            self.cookIsSurprise = false
            self.cookSpecifiedIngredients = []
            self.cookExcludedIngredients = []
            self.cookExcludedAllergens = []
            self.cookServingsCount = 1
            self.cookBudgetRange = "noLimit"
            self.cookCookTimeConstraint = "noLimit"
            
            // Eat out mode defaults
            self.eatOutDietFilter = "all"
            self.eatOutCuisine = "all"
            self.eatOutIsSurprise = false
            self.eatOutSpecifiedIngredients = []
            self.eatOutExcludedIngredients = []
            self.eatOutExcludedAllergens = []
            self.eatOutBudgetRange = "noLimit"
        }
    }
    
    init(id: String, displayName: String, email: String) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.createdAt = Date()
        self.defaultPreferences = DefaultPreferences()
    }
    
    init(data: [String: Any], id: String) {
        self.id = id
        self.displayName = data["displayName"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        
        if let timestamp = data["createdAt"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        // Default preferences
        if let prefsData = data["defaultPreferences"] as? [String: Any] {
            var prefs = DefaultPreferences()
            
            // Load new format if available
            prefs.cookDietFilter = prefsData["cookDietFilter"] as? String
            prefs.cookCuisine = prefsData["cookCuisine"] as? String
            prefs.cookIsSurprise = prefsData["cookIsSurprise"] as? Bool ?? false
            prefs.cookSpecifiedIngredients = prefsData["cookSpecifiedIngredients"] as? [String] ?? []
            prefs.cookExcludedIngredients = prefsData["cookExcludedIngredients"] as? [String] ?? []
            prefs.cookExcludedAllergens = prefsData["cookExcludedAllergens"] as? [String] ?? []
            prefs.cookServingsCount = prefsData["cookServingsCount"] as? Int ?? 1
            prefs.cookBudgetRange = prefsData["cookBudgetRange"] as? String ?? "noLimit"
            prefs.cookCookTimeConstraint = prefsData["cookCookTimeConstraint"] as? String ?? "noLimit"
            
            prefs.eatOutDietFilter = prefsData["eatOutDietFilter"] as? String
            prefs.eatOutCuisine = prefsData["eatOutCuisine"] as? String
            prefs.eatOutIsSurprise = prefsData["eatOutIsSurprise"] as? Bool ?? false
            prefs.eatOutSpecifiedIngredients = prefsData["eatOutSpecifiedIngredients"] as? [String] ?? []
            prefs.eatOutExcludedIngredients = prefsData["eatOutExcludedIngredients"] as? [String] ?? []
            prefs.eatOutExcludedAllergens = prefsData["eatOutExcludedAllergens"] as? [String] ?? []
            prefs.eatOutBudgetRange = prefsData["eatOutBudgetRange"] as? String ?? "noLimit"
            
            // Backward compatibility - migrate old format to new format
            if prefs.cookDietFilter == nil, let oldDietFilter = prefsData["dietFilter"] as? String {
                prefs.cookDietFilter = oldDietFilter
                prefs.eatOutDietFilter = oldDietFilter
            }
            
            if prefs.cookCuisine == nil, let oldCuisine = prefsData["cuisine"] as? String {
                prefs.cookCuisine = oldCuisine
                prefs.eatOutCuisine = oldCuisine
            }
            
            if let oldIsSurprise = prefsData["isSurprise"] as? Bool {
                prefs.cookIsSurprise = oldIsSurprise
                prefs.eatOutIsSurprise = oldIsSurprise
            }
            
            if let oldIngredients = prefsData["specifiedIngredients"] as? [String], !oldIngredients.isEmpty {
                prefs.cookSpecifiedIngredients = oldIngredients
                prefs.eatOutSpecifiedIngredients = oldIngredients
            }
            
            if let oldExcluded = prefsData["excludedIngredients"] as? [String], !oldExcluded.isEmpty {
                prefs.cookExcludedIngredients = oldExcluded
                prefs.eatOutExcludedIngredients = oldExcluded
            }
            
            if let oldAllergens = prefsData["excludedAllergens"] as? [String], !oldAllergens.isEmpty {
                prefs.cookExcludedAllergens = oldAllergens
                prefs.eatOutExcludedAllergens = oldAllergens
            }
            
            if let oldBudget = prefsData["budgetRange"] as? String {
                prefs.cookBudgetRange = oldBudget
                prefs.eatOutBudgetRange = oldBudget
            }
            
            if let oldTime = prefsData["cookTimeConstraint"] as? String {
                prefs.cookCookTimeConstraint = oldTime
            }
            
            self.defaultPreferences = prefs
        } else {
            self.defaultPreferences = DefaultPreferences()
        }
    }
    
    // Convert to dictionary for Firestore
    var dictionary: [String: Any] {
        return [
            "displayName": displayName,
            "email": email,
            "createdAt": Timestamp(date: createdAt),
            "defaultPreferences": [
                // Cook mode settings
                "cookDietFilter": defaultPreferences.cookDietFilter as Any,
                "cookCuisine": defaultPreferences.cookCuisine as Any,
                "cookIsSurprise": defaultPreferences.cookIsSurprise,
                "cookSpecifiedIngredients": defaultPreferences.cookSpecifiedIngredients,
                "cookExcludedIngredients": defaultPreferences.cookExcludedIngredients,
                "cookExcludedAllergens": defaultPreferences.cookExcludedAllergens,
                "cookServingsCount": defaultPreferences.cookServingsCount,
                "cookBudgetRange": defaultPreferences.cookBudgetRange,
                "cookCookTimeConstraint": defaultPreferences.cookCookTimeConstraint,
                
                // Eat out mode settings
                "eatOutDietFilter": defaultPreferences.eatOutDietFilter as Any,
                "eatOutCuisine": defaultPreferences.eatOutCuisine as Any,
                "eatOutIsSurprise": defaultPreferences.eatOutIsSurprise,
                "eatOutSpecifiedIngredients": defaultPreferences.eatOutSpecifiedIngredients,
                "eatOutExcludedIngredients": defaultPreferences.eatOutExcludedIngredients,
                "eatOutExcludedAllergens": defaultPreferences.eatOutExcludedAllergens,
                "eatOutBudgetRange": defaultPreferences.eatOutBudgetRange
            ]
        ]
    }
}

extension User.DefaultPreferences {
    init(
        cookDietFilter: String?,
        cookCuisine: String?,
        cookIsSurprise: Bool,
        cookSpecifiedIngredients: [String],
        cookExcludedIngredients: [String],
        cookExcludedAllergens: [String],
        cookServingsCount: Int,
        cookBudgetRange: String,
        cookCookTimeConstraint: String,
        eatOutDietFilter: String?,
        eatOutCuisine: String?,
        eatOutIsSurprise: Bool,
        eatOutSpecifiedIngredients: [String],
        eatOutExcludedIngredients: [String],
        eatOutExcludedAllergens: [String],
        eatOutBudgetRange: String
    ) {
        self.cookDietFilter = cookDietFilter
        self.cookCuisine = cookCuisine
        self.cookIsSurprise = cookIsSurprise
        self.cookSpecifiedIngredients = cookSpecifiedIngredients
        self.cookExcludedIngredients = cookExcludedIngredients
        self.cookExcludedAllergens = cookExcludedAllergens
        self.cookServingsCount = cookServingsCount
        self.cookBudgetRange = cookBudgetRange
        self.cookCookTimeConstraint = cookCookTimeConstraint
        self.eatOutDietFilter = eatOutDietFilter
        self.eatOutCuisine = eatOutCuisine
        self.eatOutIsSurprise = eatOutIsSurprise
        self.eatOutSpecifiedIngredients = eatOutSpecifiedIngredients
        self.eatOutExcludedIngredients = eatOutExcludedIngredients
        self.eatOutExcludedAllergens = eatOutExcludedAllergens
        self.eatOutBudgetRange = eatOutBudgetRange
    }
} 