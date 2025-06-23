import Foundation

// MARK: - Meal Mode
enum MealMode: String, CaseIterable, Codable {
    case cook = "cook"
    case eatOut = "eatOut"
    
    var displayName: String {
        switch self {
        case .cook:
            return "料理する"
        case .eatOut:
            return "外食"
        }
    }
    
    var emoji: String {
        switch self {
        case .cook:
            return "🍳"
        case .eatOut:
            return "🍽️"
        }
    }
}

// MARK: - Diet Filter
enum DietFilter: String, CaseIterable, Codable {
    case all = "all"
    case healthy = "healthy"
    case vegetarian = "vegetarian"
    case lowCarb = "lowCarb"
    case glutenFree = "glutenFree"
    case meat = "meat"
    
    var displayName: String {
        switch self {
        case .all:
            return "すべて"
        case .healthy:
            return "ヘルシー"
        case .vegetarian:
            return "ベジタリアン"
        case .lowCarb:
            return "低糖質"
        case .glutenFree:
            return "グルテンフリー"
        case .meat:
            return "肉食"
        }
    }
    
    var emoji: String {
        switch self {
        case .all:
            return "🍽️"
        case .healthy:
            return "🥗"
        case .vegetarian:
            return "🌱"
        case .lowCarb:
            return "🥬"
        case .glutenFree:
            return "🌾"
        case .meat:
            return "🥩"
        }
    }
}

// MARK: - Cuisine Option
enum CuisineOption: String, CaseIterable, Codable {
    case all = "all"
    case washoku = "washoku"
    case yoshoku = "yoshoku"
    case chuka = "chuka"
    case italian = "italian"
    case korean = "korean"
    case french = "french"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .all:
            return "すべて"
        case .washoku:
            return "和食"
        case .yoshoku:
            return "洋食"
        case .chuka:
            return "中華"
        case .italian:
            return "イタリアン"
        case .korean:
            return "韓国"
        case .french:
            return "フレンチ"
        case .other:
            return "その他"
        }
    }
    
    var emoji: String {
        switch self {
        case .all:
            return "🍽️"
        case .washoku:
            return "🍱"
        case .yoshoku:
            return "🍝"
        case .chuka:
            return "🥟"
        case .italian:
            return "🍕"
        case .korean:
            return "🇰🇷"
        case .french:
            return "🇫🇷"
        case .other:
            return "🍴"
        }
    }
}

// MARK: - Budget Option
enum BudgetOption: Codable, Hashable {
    case under500
    case between500_1000
    case between1000_1500
    case custom(min: Int, max: Int)
    case noLimit
    
    // Raw value for storage/comparison (custom implementation since we have associated values)
    var rawValue: String {
        switch self {
        case .under500:
            return "under500"
        case .between500_1000:
            return "between500_1000"
        case .between1000_1500:
            return "between1000_1500"
        case .custom(let min, let max):
            return "custom_\(min)_\(max)"
        case .noLimit:
            return "noLimit"
        }
    }
    
    // Initialize from raw value
    init?(rawValue: String) {
        switch rawValue {
        case "under500":
            self = .under500
        case "between500_1000":
            self = .between500_1000
        case "between1000_1500":
            self = .between1000_1500
        case "noLimit":
            self = .noLimit
        default:
            // Handle custom format: "custom_min_max"
            if rawValue.hasPrefix("custom_") {
                let components = rawValue.replacingOccurrences(of: "custom_", with: "").components(separatedBy: "_")
                if components.count == 2,
                   let min = Int(components[0]),
                   let max = Int(components[1]) {
                    self = .custom(min: min, max: max)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
    }
    
    var displayName: String {
        switch self {
        case .under500:
            return "¥500以下"
        case .between500_1000:
            return "¥500〜¥1000"
        case .between1000_1500:
            return "¥1000〜¥1500"
        case .custom(let min, let max):
            return "¥\(min)〜¥\(max)"
        case .noLimit:
            return "指定なし"
        }
    }
    
    var emoji: String {
        switch self {
        case .under500:
            return "💰"
        case .between500_1000:
            return "💴"
        case .between1000_1500:
            return "💵"
        case .custom:
            return "💳"
        case .noLimit:
            return "✨"
        }
    }
    
    var minValue: Int? {
        switch self {
        case .under500:
            return nil
        case .between500_1000:
            return 500
        case .between1000_1500:
            return 1000
        case .custom(let min, _):
            return min
        case .noLimit:
            return nil
        }
    }
    
    var maxValue: Int? {
        switch self {
        case .under500:
            return 500
        case .between500_1000:
            return 1000
        case .between1000_1500:
            return 1500
        case .custom(_, let max):
            return max
        case .noLimit:
            return nil
        }
    }
    
    // Static property for preset cases (for UI)
    static var presetCases: [BudgetOption] {
        return [.under500, .between500_1000, .between1000_1500, .noLimit]
    }
}

// MARK: - BudgetOption Extensions for Codable support
extension BudgetOption {
    private enum CodingKeys: String, CodingKey {
        case type, min, max
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .under500:
            try container.encode("under500", forKey: .type)
        case .between500_1000:
            try container.encode("between500_1000", forKey: .type)
        case .between1000_1500:
            try container.encode("between1000_1500", forKey: .type)
        case .custom(let min, let max):
            try container.encode("custom", forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
        case .noLimit:
            try container.encode("noLimit", forKey: .type)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "under500":
            self = .under500
        case "between500_1000":
            self = .between500_1000
        case "between1000_1500":
            self = .between1000_1500
        case "custom":
            let min = try container.decode(Int.self, forKey: .min)
            let max = try container.decode(Int.self, forKey: .max)
            self = .custom(min: min, max: max)
        case "noLimit":
            self = .noLimit
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Invalid budget option type")
        }
    }
}

// MARK: - Equatable support for BudgetOption
extension BudgetOption: Equatable {
    static func == (lhs: BudgetOption, rhs: BudgetOption) -> Bool {
        switch (lhs, rhs) {
        case (.under500, .under500),
             (.between500_1000, .between500_1000),
             (.between1000_1500, .between1000_1500),
             (.noLimit, .noLimit):
            return true
        case (.custom(let lMin, let lMax), .custom(let rMin, let rMax)):
            return lMin == rMin && lMax == rMax
        default:
            return false
        }
    }
}

// MARK: - Cook Time Option
enum CookTimeOption: String, CaseIterable, Codable {
    case tenMin = "tenMin"
    case thirtyMin = "thirtyMin"
    case sixtyMin = "sixtyMin"
    case noLimit = "noLimit"
    
    var displayName: String {
        switch self {
        case .tenMin:
            return "10分以内"
        case .thirtyMin:
            return "30分以内"
        case .sixtyMin:
            return "60分以内"
        case .noLimit:
            return "指定なし"
        }
    }
    
    var emoji: String {
        switch self {
        case .tenMin:
            return "⚡"
        case .thirtyMin:
            return "⏰"
        case .sixtyMin:
            return "🕐"
        case .noLimit:
            return "♾️"
        }
    }
    
    var maxMinutes: Int? {
        switch self {
        case .tenMin:
            return 10
        case .thirtyMin:
            return 30
        case .sixtyMin:
            return 60
        case .noLimit:
            return nil
        }
    }
}

// MARK: - Sort Option
enum SortOption: String, CaseIterable {
    case dateDescending = "dateDescending"
    case dateAscending = "dateAscending"
    case rating = "rating"
    
    var displayName: String {
        switch self {
        case .dateDescending:
            return "新しい順"
        case .dateAscending:
            return "古い順"
        case .rating:
            return "評価順"
        }
    }
}

// MARK: - Result Type
enum ResultType: String, CaseIterable, Codable {
    case recipe = "recipe"
    case eatingOutMeal = "eatingOutMeal"
    case restaurant = "restaurant"
    
    var displayName: String {
        switch self {
        case .recipe:
            return "レシピ"
        case .eatingOutMeal:
            return "外食メニュー"
        case .restaurant:
            return "レストラン"
        }
    }
}

// MARK: - History Tab
enum HistoryTab: String, CaseIterable {
    case cuisine = "cuisine"
    case restaurant = "restaurant"
    
    var displayName: String {
        switch self {
        case .cuisine:
            return "料理"
        case .restaurant:
            return "レストラン"
        }
    }
    
    var iconName: String {
        switch self {
        case .cuisine:
            return "fork.knife"
        case .restaurant:
            return "building.2"
        }
    }
}

// MARK: - Restaurant Sort Option
enum RestaurantSortOption: String, CaseIterable {
    case distance = "distance"
    case rating = "rating"
    case name = "name"
    
    var displayName: String {
        switch self {
        case .distance:
            return "距離順"
        case .rating:
            return "評価順"
        case .name:
            return "名前順"
        }
    }
}

// MARK: - Common Ingredients
enum CommonIngredient: String, CaseIterable {
    // Meats (3)
    case chicken = "鶏肉"
    case pork = "豚肉" 
    case beef = "牛肉"
    
    // Fish & Eggs (3)
    case shrimp = "海老"
    case salmon = "鮭"
    case egg = "卵"
    
    // Vegetables (3)
    case onion = "玉ねぎ"
    case cabbage = "キャベツ"
    case carrot = "人参"
    
    // Main/Staples (3) 
    case rice = "ご飯"
    case tofu = "豆腐"
    case potato = "じゃがいも"
    
    var displayName: String {
        return self.rawValue
    }
    
    var emoji: String {
        switch self {
        case .chicken:
            return "🐔"
        case .pork:
            return "🐷"
        case .beef:
            return "🐮"
        case .shrimp:
            return "🦐"
        case .salmon:
            return "🐟"
        case .egg:
            return "🥚"
        case .onion:
            return "🧅"
        case .cabbage:
            return "🥬"
        case .carrot:
            return "🥕"
        case .rice:
            return "🍚"
        case .tofu:
            return "🧈"
        case .potato:
            return "🥔"
        }
    }
} 