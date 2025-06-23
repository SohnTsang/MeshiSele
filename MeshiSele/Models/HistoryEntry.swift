import Foundation
import FirebaseFirestore

struct HistoryEntry: Identifiable, Codable, Equatable {
    let id: String
    let timestamp: Date
    let mealMode: String // "cook" or "eatOut"
    let dietFilter: String
    let cuisine: String?
    let isSurprise: Bool
    let specifiedIngredients: [String]
    let excludedIngredients: [String]
    let servingsCount: Int
    let budgetRange: String
    let cookTimeConstraint: String
    let resultType: String // "recipe" or "restaurant"
    let resultId: String
    let resultName: String // Store the actual name of the recipe/restaurant
    var rating: Double? // 0.0-5.0 stars
    var userComment: String?
    let isDecided: Bool // Whether the user actually decided on this meal or just viewed it
    let restaurantCategories: [String]? // Store actual restaurant categories for restaurants
    
    // Add displayName property
    var displayName: String {
        return resultName
    }
    
    // Computed properties for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("date_format", comment: "Date format")
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: timestamp)
    }
    
    var mealModeDisplayName: String {
        switch mealMode {
        case "cook":
            return "cook".localized
        case "eatOut":
            return "eat_out".localized
        default:
            return mealMode
        }
    }
    
    var dietFilterDisplayName: String {
        switch dietFilter {
        case "all":
            return "all".localized
        case "healthy":
            return "healthy".localized
        case "vegetarian":
            return "vegetarian".localized
        case "gluten_free":
            return "gluten_free".localized
        case "keto":
            return "keto".localized
        default:
            return dietFilter
        }
    }
    
    var budgetRangeDisplayName: String {
        switch budgetRange {
        case "under_500", "under500":
            return "under_500".localized
        case "500_1000", "between500_1000":
            return "500_1000".localized
        case "1000_1500", "between1000_1500":
            return "1000_1500".localized
        case "no_limit", "noLimit":
            return "no_limit".localized
        default:
            // Handle custom budget format "custom_min_max"
            if budgetRange.hasPrefix("custom_") {
                let components = budgetRange.replacingOccurrences(of: "custom_", with: "").components(separatedBy: "_")
                if components.count == 2, let min = components.first, let max = components.last {
                    return "¥\(min)〜¥\(max)"
                }
            }
            return budgetRange
        }
    }
    
    var cookTimeConstraintDisplayName: String {
        switch cookTimeConstraint {
        case "ten_min":
            return "ten_min".localized
        case "thirty_min":
            return "thirty_min".localized
        case "sixty_min":
            return "sixty_min".localized
        case "no_time_limit", "noLimit":
            return "no_time_limit".localized
        default:
            return cookTimeConstraint
        }
    }
    
    var cuisineDisplayName: String {
        // For both restaurants and recipes, use the original cuisine selection from spinning
        // This shows what the user originally wanted to eat, not the restaurant's categories
        guard let cuisine = cuisine, !cuisine.isEmpty else { 
            // Fallback: if no cuisine is stored, use restaurant categories for restaurants
            if resultType == "restaurant" {
                if let categories = restaurantCategories, !categories.isEmpty {
                    let filteredCategories = categories.filter { category in
                        !["restaurant", "establishment", "飲食店", "レストラン"].contains(category)
                    }
                    return filteredCategories.first ?? categories.first ?? "飲食店"
                } else {
                    return "飲食店"
                }
            }
            return "" 
        }
        
        // Display the original cuisine selection for both recipes and restaurants
        switch cuisine {
        case "washoku":
            return "washoku".localized
        case "yoshoku":
            return "yoshoku".localized
        case "chuka":
            return "chuka".localized
        case "italian":
            return "italian".localized
        case "all":
            return "all".localized
        case "ramen":
            return "ラーメン"
        case "sushi":
            return "寿司"
        case "yakiniku":
            return "焼肉"
        case "izakaya":
            return "居酒屋"
        case "cafe":
            return "カフェ"
        case "fastfood":
            return "ファストフード"
        case "other":
            return "other".localized
        default:
            return cuisine
        }
    }
    
    var ratingDisplay: String {
        guard let rating = rating else { return "未評価" }
        let fullStars = Int(rating)
        let hasHalfStar = rating - Double(fullStars) >= 0.5
        
        var stars = String(repeating: "★", count: fullStars)
        if hasHalfStar {
            stars += "☆"
        }
        let emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
        stars += String(repeating: "☆", count: max(0, emptyStars))
        
        return stars
    }
    
    init(
        id: String? = nil,
        mealMode: String,
        dietFilter: String,
        cuisine: String? = nil,
        isSurprise: Bool,
        specifiedIngredients: [String],
        excludedIngredients: [String],
        servingsCount: Int,
        budgetRange: String,
        cookTimeConstraint: String,
        resultType: String,
        resultId: String,
        resultName: String,
        rating: Double? = nil,
        userComment: String? = nil,
        isDecided: Bool,
        restaurantCategories: [String]? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.timestamp = Date()
        self.mealMode = mealMode
        self.dietFilter = dietFilter
        self.cuisine = cuisine
        self.isSurprise = isSurprise
        self.specifiedIngredients = specifiedIngredients
        self.excludedIngredients = excludedIngredients
        self.servingsCount = servingsCount
        self.budgetRange = budgetRange
        self.cookTimeConstraint = cookTimeConstraint
        self.resultType = resultType
        self.resultId = resultId
        self.resultName = resultName
        self.rating = rating
        self.userComment = userComment
        self.isDecided = isDecided
        self.restaurantCategories = restaurantCategories
    }
    
    init(data: [String: Any], id: String) {
        self.id = id
        
        if let timestamp = data["timestamp"] as? Timestamp {
            self.timestamp = timestamp.dateValue()
        } else {
            self.timestamp = Date()
        }
        
        self.mealMode = data["mealMode"] as? String ?? ""
        self.dietFilter = data["dietFilter"] as? String ?? ""
        self.cuisine = data["cuisine"] as? String
        self.isSurprise = data["isSurprise"] as? Bool ?? false
        self.specifiedIngredients = data["specifiedIngredients"] as? [String] ?? []
        self.excludedIngredients = data["excludedIngredients"] as? [String] ?? []
        self.servingsCount = data["servingsCount"] as? Int ?? 1
        self.budgetRange = data["budgetRange"] as? String ?? "no_limit"
        self.cookTimeConstraint = data["cookTimeConstraint"] as? String ?? "no_time_limit"
        self.resultType = data["resultType"] as? String ?? ""
        self.resultId = data["resultId"] as? String ?? ""
        self.resultName = data["resultName"] as? String ?? ""
        self.rating = data["rating"] as? Double
        self.userComment = data["userComment"] as? String
        self.isDecided = data["isDecided"] as? Bool ?? false
        self.restaurantCategories = data["restaurantCategories"] as? [String]
    }
    
    // Convert to dictionary for Firestore
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "timestamp": Timestamp(date: timestamp),
            "mealMode": mealMode,
            "dietFilter": dietFilter,
            "isSurprise": isSurprise,
            "specifiedIngredients": specifiedIngredients,
            "excludedIngredients": excludedIngredients,
            "servingsCount": servingsCount,
            "budgetRange": budgetRange,
            "cookTimeConstraint": cookTimeConstraint,
            "resultType": resultType,
            "resultId": resultId,
            "resultName": resultName,
            "isDecided": isDecided
        ]
        
        if let cuisine = cuisine {
            dict["cuisine"] = cuisine
        }
        
        if let rating = rating {
            dict["rating"] = rating
        }
        
        if let userComment = userComment {
            dict["userComment"] = userComment
        }
        
        if let restaurantCategories = restaurantCategories {
            dict["restaurantCategories"] = restaurantCategories
        }
        
        return dict
    }
    
    // Create filter parameters for re-execution
    var filterParameters: [String: Any] {
        return [
            "mealMode": mealMode,
            "dietFilter": dietFilter,
            "cuisine": cuisine as Any,
            "isSurprise": isSurprise,
            "specifiedIngredients": specifiedIngredients,
            "excludedIngredients": excludedIngredients,
            "servingsCount": servingsCount,
            "budgetRange": budgetRange,
            "cookTimeConstraint": cookTimeConstraint
        ]
    }
    
    // MARK: - Equatable Conformance
    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        return lhs.id == rhs.id &&
               lhs.timestamp == rhs.timestamp &&
               lhs.mealMode == rhs.mealMode &&
               lhs.dietFilter == rhs.dietFilter &&
               lhs.cuisine == rhs.cuisine &&
               lhs.resultType == rhs.resultType &&
               lhs.resultId == rhs.resultId &&
               lhs.isSurprise == rhs.isSurprise &&
               lhs.specifiedIngredients == rhs.specifiedIngredients &&
               lhs.excludedIngredients == rhs.excludedIngredients &&
               lhs.servingsCount == rhs.servingsCount &&
               lhs.budgetRange == rhs.budgetRange &&
               lhs.cookTimeConstraint == rhs.cookTimeConstraint &&
               lhs.rating == rhs.rating &&
               lhs.userComment == rhs.userComment &&
               lhs.isDecided == rhs.isDecided
    }
} 