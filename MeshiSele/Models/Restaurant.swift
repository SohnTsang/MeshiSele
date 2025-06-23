import Foundation
import MapKit
import CoreLocation
import FirebaseFirestore

struct Restaurant: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let phoneNumber: String?
    let website: String?
    let rating: Double?
    let cuisine: String?
    let priceLevel: Int? // 1-4 scale
    let coordinate: Coordinate
    let distance: Double? // in meters from user location
    let imageURL: String?
    let isOpen: Bool?
    let openingHours: String?
    let popularityCount: Int // how many people chose this restaurant
    let createdAt: Date
    let updatedAt: Date
    
    // Additional properties
    let placeId: String?
    let categories: [String]
    
    // Google-specific properties
    let googleRating: Double?
    let googleReviewCount: Int?
    let googlePhotoURL: String?
    let googleRestaurantTypes: [String] // Actual restaurant types from Google
    
    struct Coordinate: Codable, Equatable {
        let latitude: Double
        let longitude: Double
        
        var clLocation: CLLocation {
            return CLLocation(latitude: latitude, longitude: longitude)
        }
        
        var clCoordinate: CLLocationCoordinate2D {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    init(mapItem: MKMapItem, userLocation: CLLocation?) {
        self.id = UUID().uuidString
        self.name = mapItem.name ?? "Unknown Restaurant"
        self.address = mapItem.placemark.title ?? "住所不明"
        self.phoneNumber = mapItem.phoneNumber
        self.website = mapItem.url?.absoluteString
        
        // MapKit doesn't provide ratings directly, would need Places API for this
        self.rating = nil
        self.cuisine = nil
        self.priceLevel = nil
        
        self.coordinate = Coordinate(
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude
        )
        
        if let userLocation = userLocation {
            let restaurantLocation = CLLocation(
                latitude: mapItem.placemark.coordinate.latitude,
                longitude: mapItem.placemark.coordinate.longitude
            )
            self.distance = userLocation.distance(from: restaurantLocation)
        } else {
            self.distance = nil
        }
        
        self.imageURL = nil
        self.isOpen = nil
        self.openingHours = nil
        self.popularityCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        
        // Set additional properties
        self.placeId = mapItem.placemark.title // Use title as placeholder for placeId
        
        // Extract categories from MapKit and infer from name
        var extractedCategories: [String] = []
        
        // Get MapKit point of interest category if available
        if #available(iOS 13.0, *) {
            if let poiCategory = mapItem.pointOfInterestCategory {
                switch poiCategory {
                case .restaurant:
                    extractedCategories.append("レストラン")
                case .cafe:
                    extractedCategories.append("カフェ")
                case .bakery:
                    extractedCategories.append("ベーカリー")
                case .brewery:
                    extractedCategories.append("醸造所")
                case .winery:
                    extractedCategories.append("ワイナリー")
                case .foodMarket:
                    extractedCategories.append("フードマーケット")
                default:
                    extractedCategories.append("飲食店")
                }
            }
        }
        
        // Infer categories from restaurant name
        let name = mapItem.name?.lowercased() ?? ""
        let inferredCategories = Self.inferCategoriesFromName(name)
        extractedCategories.append(contentsOf: inferredCategories)
        
        // Use extracted categories or fallback to generic
        self.categories = extractedCategories.isEmpty ? ["飲食店"] : extractedCategories
        
        // Google properties not available from MapKit
        self.googleRating = nil
        self.googleReviewCount = nil
        self.googlePhotoURL = nil
        self.googleRestaurantTypes = []
    }
    
    // Helper method to infer restaurant categories from name
    private static func inferCategoriesFromName(_ name: String) -> [String] {
        var categories: [String] = []
        
        // Japanese restaurant types
        let categoryKeywords: [String: String] = [
            "ラーメン": "ラーメン",
            "らーめん": "ラーメン",
            "麺": "ラーメン",
            "うどん": "うどん",
            "そば": "そば",
            "蕎麦": "そば",
            "寿司": "寿司",
            "すし": "寿司",
            "鮨": "寿司",
            "焼肉": "焼肉",
            "焼鳥": "焼鳥",
            "やきとり": "焼鳥",
            "居酒屋": "居酒屋",
            "カフェ": "カフェ",
            "喫茶": "カフェ",
            "コーヒー": "カフェ",
            "珈琲": "カフェ",
            "ピザ": "ピザ",
            "パスタ": "イタリアン",
            "イタリアン": "イタリアン",
            "フレンチ": "フレンチ",
            "中華": "中華",
            "中国": "中華",
            "韓国": "韓国料理",
            "カルビ": "韓国料理",
            "ビビンバ": "韓国料理", 
            "カレー": "カレー",
            "インド": "インド料理",
            "タイ": "タイ料理",
            "ベトナム": "ベトナム料理",
            "定食": "定食",
            "弁当": "弁当",
            "丼": "丼",
            "どんぶり": "丼",
            "天ぷら": "天ぷら",
            "とんかつ": "とんかつ",
            "豚かつ": "とんかつ",
            "ハンバーガー": "ハンバーガー",
            "バーガー": "ハンバーガー",
            "ファストフード": "ファストフード",
            "ファミレス": "ファミリーレストラン",
            "回転寿司": "回転寿司",
            "お好み焼き": "お好み焼き",
            "たこ焼き": "たこ焼き",
            "ステーキ": "ステーキ",
            "バー": "バー",
            "酒場": "居酒屋",
            "スイーツ": "スイーツ",
            "ケーキ": "スイーツ",
            "パン": "ベーカリー",
            "ベーカリー": "ベーカリー"
        ]
        
        for (keyword, category) in categoryKeywords {
            if name.contains(keyword) {
                if !categories.contains(category) {
                    categories.append(category)
                }
            }
        }
        
        return categories
    }
    
    // For data initialization (Firebase/fallback data)
    init(data: [String: Any], id: String? = nil) {
        self.id = id ?? data["id"] as? String ?? UUID().uuidString
        self.name = data["name"] as? String ?? ""
        self.address = data["address"] as? String ?? ""
        self.phoneNumber = data["phoneNumber"] as? String
        self.website = data["website"] as? String
        self.rating = data["rating"] as? Double
        self.cuisine = data["cuisine"] as? String
        self.priceLevel = data["priceLevel"] as? Int
        self.imageURL = data["imageURL"] as? String
        self.isOpen = data["isOpen"] as? Bool
        self.openingHours = data["openingHours"] as? String
        self.popularityCount = data["popularityCount"] as? Int ?? 0
        
        // Parse coordinate
        if let lat = data["latitude"] as? Double,
           let lon = data["longitude"] as? Double {
            self.coordinate = Coordinate(latitude: lat, longitude: lon)
        } else {
            self.coordinate = Coordinate(latitude: 0, longitude: 0)
        }
        
        self.distance = data["distance"] as? Double
        
        // Dates
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
        
        // Additional properties
        self.placeId = data["placeId"] as? String
        self.categories = data["categories"] as? [String] ?? ["restaurant"]
        
        // Google properties
        self.googleRating = data["googleRating"] as? Double
        self.googleReviewCount = data["googleReviewCount"] as? Int
        self.googlePhotoURL = data["googlePhotoURL"] as? String
        self.googleRestaurantTypes = data["googleRestaurantTypes"] as? [String] ?? []
    }
    
    // Convenience initializer for Google Places
    init(
        id: String,
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        distance: CLLocationDistance?,
        rating: Double?,
        reviewCount: Int?,
        priceLevel: Int?,
        website: String?,
        phoneNumber: String?,
        photoURL: String?,
        isOpen: Bool?,
        types: [String]
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phoneNumber = phoneNumber
        self.website = website
        self.rating = rating
        self.cuisine = nil
        self.priceLevel = priceLevel
        
        self.coordinate = Coordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        self.distance = distance
        self.imageURL = photoURL
        self.isOpen = isOpen
        self.openingHours = nil
        self.popularityCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        
        self.placeId = id
        self.categories = Self.convertGoogleTypesToCategories(types)
        
        // Google-specific properties
        self.googleRating = rating
        self.googleReviewCount = reviewCount
        self.googlePhotoURL = photoURL
        self.googleRestaurantTypes = types
    }
    
    // Helper method to convert Google types to readable categories
    static func convertGoogleTypesToCategories(_ types: [String]) -> [String] {
        var categories: [String] = []
        
        for type in types {
            switch type.lowercased() {
            case "restaurant":
                categories.append("レストラン")
            case "meal_takeaway":
                categories.append("テイクアウト")
            case "meal_delivery":
                categories.append("デリバリー")
            case "cafe":
                categories.append("カフェ")
            case "bakery":
                categories.append("ベーカリー")
            case "bar":
                categories.append("バー")
            case "night_club":
                categories.append("クラブ")
            case "fast_food":
                categories.append("ファストフード")
            case "pizza":
                categories.append("ピザ")
            case "hamburger":
                categories.append("ハンバーガー")
            case "sushi":
                categories.append("寿司")
            case "ramen":
                categories.append("ラーメン")
            case "japanese_restaurant":
                categories.append("和食")
            case "chinese_restaurant":
                categories.append("中華")
            case "korean_restaurant":
                categories.append("韓国料理")
            case "thai_restaurant":
                categories.append("タイ料理")
            case "indian_restaurant":
                categories.append("インド料理")
            case "italian_restaurant":
                categories.append("イタリアン")
            case "french_restaurant":
                categories.append("フレンチ")
            case "mexican_restaurant":
                categories.append("メキシカン")
            case "american_restaurant":
                categories.append("アメリカン")
            case "seafood_restaurant":
                categories.append("シーフード")
            case "steakhouse":
                categories.append("ステーキハウス")
            case "barbecue_restaurant":
                categories.append("焼肉")
            case "ice_cream_shop":
                categories.append("アイスクリーム")
            case "dessert":
                categories.append("デザート")
            default:
                break
            }
        }
        
        return categories.isEmpty ? ["レストラン"] : categories
    }
    
    // Convert to dictionary for Firestore
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "address": address,
            "latitude": coordinate.latitude,
            "longitude": coordinate.longitude,
            "popularityCount": popularityCount,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "categories": categories
        ]
        
        if let phoneNumber = phoneNumber { dict["phoneNumber"] = phoneNumber }
        if let website = website { dict["website"] = website }
        if let rating = rating { dict["rating"] = rating }
        if let cuisine = cuisine { dict["cuisine"] = cuisine }
        if let priceLevel = priceLevel { dict["priceLevel"] = priceLevel }
        if let imageURL = imageURL { dict["imageURL"] = imageURL }
        if let isOpen = isOpen { dict["isOpen"] = isOpen }
        if let openingHours = openingHours { dict["openingHours"] = openingHours }
        if let distance = distance { dict["distance"] = distance }
        if let placeId = placeId { dict["placeId"] = placeId }
        if let googleRating = googleRating { dict["googleRating"] = googleRating }
        if let googleReviewCount = googleReviewCount { dict["googleReviewCount"] = googleReviewCount }
        if let googlePhotoURL = googlePhotoURL { dict["googlePhotoURL"] = googlePhotoURL }
        if !googleRestaurantTypes.isEmpty { dict["googleRestaurantTypes"] = googleRestaurantTypes }
        
        return dict
    }
    
    var formattedDistance: String {
        guard let distance = distance else { return "" }
        
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
    
    var formattedRating: String {
        // Prioritize Google rating, fallback to general rating
        let displayRating = googleRating ?? rating
        guard let rating = displayRating else { return "" }
        return String(format: "★ %.1f", rating)
    }
    
    var formattedGoogleRating: String {
        guard let googleRating = googleRating else { return "" }
        let reviewText = googleReviewCount != nil ? " (\(googleReviewCount!)件)" : ""
        return String(format: "★ %.1f%@", googleRating, reviewText)
    }
    
    var formattedPriceLevel: String {
        guard let priceLevel = priceLevel else { return "" }
        return String(repeating: "¥", count: priceLevel)
    }
    
    // Open in Maps
    func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate.clCoordinate))
        mapItem.name = name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // Call restaurant
    func callRestaurant() {
        guard let phoneNumber = phoneNumber,
              let url = URL(string: "tel://\(phoneNumber.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: ""))") else {
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    // Visit website
    func openWebsite() {
        guard let website = website,
              let url = URL(string: website) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
} 