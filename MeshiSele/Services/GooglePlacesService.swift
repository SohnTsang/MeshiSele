import Foundation
import CoreLocation
import OSLog

// MARK: - Google Places API Models
struct GooglePlacesResponse: Codable {
    let places: [GooglePlace]
    let nextPageToken: String?
}

struct GooglePlace: Codable {
    let id: String
    let displayName: GoogleDisplayName
    let formattedAddress: String?
    let location: GoogleLocation
    let rating: Double?
    let userRatingCount: Int?
    let photos: [GooglePhoto]?
    let priceLevel: String?
    let types: [String]?
    let businessStatus: String?
    let currentOpeningHours: GoogleOpeningHours?
    let websiteUri: String?
    let internationalPhoneNumber: String?
}

struct GoogleDisplayName: Codable {
    let text: String
    let languageCode: String?
}

struct GoogleLocation: Codable {
    let latitude: Double
    let longitude: Double
}

struct GooglePhoto: Codable {
    let name: String
    let widthPx: Int?
    let heightPx: Int?
}

struct GoogleOpeningHours: Codable {
    let openNow: Bool?
}

struct GooglePlacesRequest: Codable {
    let textQuery: String
    let pageSize: Int?
    var pageToken: String?
    let locationBias: GoogleLocationBias?
    let includedType: String?
    let minRating: Double?
    let priceLevels: [String]?
    let openNow: Bool?
    let strictTypeFiltering: Bool?
    let rankPreference: String?
    let languageCode: String?
}

struct GoogleLocationBias: Codable {
    let circle: GoogleCircle
}

struct GoogleCircle: Codable {
    let center: GoogleLocation
    let radius: Double
}

// MARK: - Google Places Service
class GooglePlacesService: ObservableObject {
    static let shared = GooglePlacesService()
    
    private let logger = Logger(subsystem: "MeshiSele", category: "GooglePlacesService")
    private let baseURL = "https://places.googleapis.com/v1/places:searchText"
    
    // Google Places API key from configuration
    private let apiKey = APIKeys.currentGooglePlacesAPIKey
    
    private let session = URLSession.shared
    private let searchQueue = DispatchQueue(label: "com.meshisele.googleplaces.search", qos: .userInitiated)
    private var lastResponse: GooglePlacesResponse?
    
    private init() {}
    
    // MARK: - Primary Restaurant Search Methods
    
    /// Search restaurants using Google Places API with meal-specific keywords
    func searchRestaurantsForMeal(
        mealKeywords: String,
        cuisine: String,
        userLocation: CLLocation?,
        budget: BudgetOption,
        excludedIngredients: [String],
        limit: Int = 20,
        completion: @escaping ([Restaurant]) -> Void
    ) {
        logger.info("🏢 GooglePlacesService: Searching restaurants for meal: '\(mealKeywords)'")
        
        searchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Build optimized search query for Google Places
            let searchQuery = self.buildOptimizedSearchQuery(
                mealKeywords: mealKeywords,
                cuisine: cuisine
            )
            
            logger.info("🏢 GooglePlacesService: Using search query: '\(searchQuery)'")
            
            let request = GooglePlacesRequest(
                textQuery: searchQuery,
                pageSize: 20, // Google Places API max is 20 per request
                pageToken: nil,
                locationBias: self.createLocationBias(from: userLocation),
                includedType: "restaurant", // Restrict to restaurants only
                minRating: 3.0, // Only show restaurants with decent ratings
                priceLevels: self.convertBudgetToPriceLevels(budget),
                openNow: nil, // Don't filter by open status for more results
                strictTypeFiltering: true, // Only return restaurants
                rankPreference: "RELEVANCE", // Prioritize relevance for meal keywords
                languageCode: "ja" // Japanese for better local results
            )
            
            // Fetch multiple pages to get up to 80 restaurants
            self.fetchMultiplePages(
                initialRequest: request,
                targetCount: min(limit, 80),
                userLocation: userLocation,
                excludedIngredients: excludedIngredients,
                completion: completion
            )
        }
    }
    
    /// Search for a single random restaurant for the お任せ mode
    func searchRandomRestaurantForMeal(
        mealKeywords: String,
        cuisine: String,
        userLocation: CLLocation?,
        budget: BudgetOption,
        excludedIngredients: [String],
        completion: @escaping (Restaurant?) -> Void
    ) {
        searchRestaurantsForMeal(
            mealKeywords: mealKeywords,
            cuisine: cuisine,
            userLocation: userLocation,
            budget: budget,
            excludedIngredients: excludedIngredients,
            limit: 20
        ) { restaurants in
            // Return a random restaurant from the results
            let randomRestaurant = restaurants.randomElement()
            completion(randomRestaurant)
        }
    }
    
    // MARK: - Multi-Page Fetching
    
    private func fetchMultiplePages(
        initialRequest: GooglePlacesRequest,
        targetCount: Int,
        userLocation: CLLocation?,
        excludedIngredients: [String],
        allRestaurants: [Restaurant] = [],
        completion: @escaping ([Restaurant]) -> Void
    ) {
        performGooglePlacesSearch(request: initialRequest) { [weak self] places in
            guard let self = self else {
                DispatchQueue.main.async { completion(allRestaurants) }
                return
            }
            
            // Convert Google Places to Restaurant objects
            let newRestaurants = places.compactMap { place in
                self.convertGooglePlaceToRestaurant(
                    place: place,
                    userLocation: userLocation,
                    excludedIngredients: excludedIngredients
                )
            }
            
            // Filter by excluded ingredients in restaurant names
            let filteredNewRestaurants = newRestaurants.filter { restaurant in
                !self.containsExcludedIngredients(
                    restaurantName: restaurant.name,
                    excludedIngredients: excludedIngredients
                )
            }
            
            let combinedRestaurants = allRestaurants + filteredNewRestaurants
            
            self.logger.info("🏢 GooglePlacesService: Fetched \(filteredNewRestaurants.count) new restaurants, total: \(combinedRestaurants.count)")
            
            // Check if we need more restaurants and have a next page token
            if combinedRestaurants.count < targetCount,
               let response = self.lastResponse,
               let nextPageToken = response.nextPageToken,
               !nextPageToken.isEmpty {
                
                // Create request for next page
                var nextRequest = initialRequest
                nextRequest.pageToken = nextPageToken
                
                // Add delay to respect Google's rate limiting
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                    self.fetchMultiplePages(
                        initialRequest: nextRequest,
                        targetCount: targetCount,
                        userLocation: userLocation,
                        excludedIngredients: excludedIngredients,
                        allRestaurants: combinedRestaurants,
                        completion: completion
                    )
                }
            } else {
                // Return final results
                DispatchQueue.main.async {
                    completion(Array(combinedRestaurants.prefix(targetCount)))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func buildOptimizedSearchQuery(mealKeywords: String, cuisine: String) -> String {
        // Create more specific search queries for Google Places API
        var queryComponents: [String] = []
        
        // Primary meal keyword
        queryComponents.append(mealKeywords)
        
        // Add cuisine if specified and different from meal keywords
        if !cuisine.isEmpty && cuisine.lowercased() != mealKeywords.lowercased() {
            queryComponents.append(cuisine)
        }
        
        // Add location context for better results (will be overridden by locationBias)
        queryComponents.append("restaurant")
        
        // Join with spaces for natural language query
        let query = queryComponents.joined(separator: " ")
        
        logger.info("🏢 GooglePlacesService: Built search query: '\(query)'")
        return query
    }
    
    private func createLocationBias(from location: CLLocation?) -> GoogleLocationBias? {
        guard let location = location else {
            // Default to Tokyo if no location available
            logger.info("🏢 GooglePlacesService: No user location, using default Tokyo location")
            return GoogleLocationBias(
                circle: GoogleCircle(
                    center: GoogleLocation(latitude: 35.6762, longitude: 139.6503),
                    radius: 10000.0 // 10km radius
                )
            )
        }
        
        return GoogleLocationBias(
            circle: GoogleCircle(
                center: GoogleLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ),
                radius: 5000.0 // 5km radius for user location
            )
        )
    }
    
    private func convertBudgetToPriceLevels(_ budget: BudgetOption) -> [String]? {
        switch budget {
        case .under500:
            return ["PRICE_LEVEL_INEXPENSIVE"]
        case .between500_1000:
            return ["PRICE_LEVEL_INEXPENSIVE", "PRICE_LEVEL_MODERATE"]
        case .between1000_1500:
            return ["PRICE_LEVEL_MODERATE"]
        case .custom(let min, let max):
            return convertCustomBudgetToPriceLevels(min: min, max: max)
        case .noLimit:
            return nil // Include all price levels
        }
    }
    
    private func convertCustomBudgetToPriceLevels(min: Int, max: Int) -> [String] {
        var priceLevels: [String] = []
        
        // Map custom budget ranges to Google's price levels
        // PRICE_LEVEL_INEXPENSIVE: ~¥500 or less
        // PRICE_LEVEL_MODERATE: ~¥500-¥1500  
        // PRICE_LEVEL_EXPENSIVE: ~¥1500-¥3000
        // PRICE_LEVEL_VERY_EXPENSIVE: ~¥3000+
        
        if min <= 500 {
            priceLevels.append("PRICE_LEVEL_INEXPENSIVE")
        }
        
        if (min <= 1500 && max >= 500) {
            priceLevels.append("PRICE_LEVEL_MODERATE")
        }
        
        if (min <= 3000 && max >= 1500) {
            priceLevels.append("PRICE_LEVEL_EXPENSIVE")
        }
        
        if max >= 3000 {
            priceLevels.append("PRICE_LEVEL_VERY_EXPENSIVE")
        }
        
        // If no price levels match, include inexpensive as fallback
        if priceLevels.isEmpty {
            priceLevels.append("PRICE_LEVEL_INEXPENSIVE")
        }
        
        return priceLevels
    }
    
    private func performGooglePlacesSearch(
        request: GooglePlacesRequest,
        completion: @escaping ([GooglePlace]) -> Void
    ) {
        guard APIKeys.isGooglePlacesAPIKeyConfigured else {
            logger.error("🏢 GooglePlacesService: ❌ Google Places API key not configured. Please add your API key to APIKeys.swift")
            completion([])
            return
        }
        
        guard let url = URL(string: baseURL) else {
            logger.error("🏢 GooglePlacesService: ❌ Invalid URL")
            completion([])
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        
        // Set field mask to only request necessary fields (cost optimization)
        let fieldMask = APIConfiguration.standardFieldMask
        
        urlRequest.setValue(fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            logger.info("🏢 GooglePlacesService: Making API request...")
            
            session.dataTask(with: urlRequest) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.logger.error("🏢 GooglePlacesService: ❌ Network error: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let data = data else {
                    self.logger.error("🏢 GooglePlacesService: ❌ No data received")
                    completion([])
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    self.logger.info("🏢 GooglePlacesService: Response status: \(httpResponse.statusCode)")
                }
                
                do {
                    let placesResponse = try JSONDecoder().decode(GooglePlacesResponse.self, from: data)
                    self.lastResponse = placesResponse // Store for pagination
                    self.logger.info("🏢 GooglePlacesService: ✅ Successfully parsed \(placesResponse.places.count) places")
                    completion(placesResponse.places)
                } catch {
                    self.logger.error("🏢 GooglePlacesService: ❌ JSON decode error: \(error.localizedDescription)")
                    // Try to log raw response for debugging
                    if let responseString = String(data: data, encoding: .utf8) {
                        self.logger.error("🏢 GooglePlacesService: Raw response: \(responseString)")
                    }
                    completion([])
                }
            }.resume()
            
        } catch {
            logger.error("🏢 GooglePlacesService: ❌ JSON encode error: \(error.localizedDescription)")
            completion([])
        }
    }
    
    private func convertGooglePlaceToRestaurant(
        place: GooglePlace,
        userLocation: CLLocation?,
        excludedIngredients: [String]
    ) -> Restaurant? {
        // Convert Google Place to Restaurant model
        let coordinate = CLLocationCoordinate2D(
            latitude: place.location.latitude,
            longitude: place.location.longitude
        )
        
        let restaurantLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        // Calculate distance if user location is available
        let distance: CLLocationDistance? = userLocation?.distance(from: restaurantLocation)
        
        // Get photo URL if available
        var photoURL: String?
        if let photo = place.photos?.first {
            photoURL = "https://places.googleapis.com/v1/\(photo.name)/media?maxWidthPx=400&key=\(apiKey)"
        }
        
        // Convert price level
        let priceLevel = convertGooglePriceLevel(place.priceLevel)
        
        return Restaurant(
            id: place.id,
            name: place.displayName.text,
            address: place.formattedAddress ?? "",
            coordinate: coordinate,
            distance: distance,
            rating: place.rating,
            reviewCount: place.userRatingCount,
            priceLevel: priceLevel,
            website: place.websiteUri,
            phoneNumber: place.internationalPhoneNumber,
            photoURL: photoURL,
            isOpen: place.currentOpeningHours?.openNow,
            types: place.types ?? []
        )
    }
    
    private func convertGooglePriceLevel(_ priceLevel: String?) -> Int {
        switch priceLevel {
        case "PRICE_LEVEL_INEXPENSIVE":
            return 1
        case "PRICE_LEVEL_MODERATE":
            return 2
        case "PRICE_LEVEL_EXPENSIVE":
            return 3
        case "PRICE_LEVEL_VERY_EXPENSIVE":
            return 4
        default:
            return 0 // Unknown/Free
        }
    }
    
    private func containsExcludedIngredients(
        restaurantName: String,
        excludedIngredients: [String]
    ) -> Bool {
        let name = restaurantName.lowercased()
        for ingredient in excludedIngredients {
            if name.contains(ingredient.lowercased()) {
                return true
            }
        }
        return false
    }
}

// MARK: - Restaurant Model Extension
extension Restaurant {
    /// Initializer from Google Place data
    init?(googlePlace: GooglePlace, userLocation: CLLocation?) {
        let coordinate = CLLocationCoordinate2D(
            latitude: googlePlace.location.latitude,
            longitude: googlePlace.location.longitude
        )
        
        let restaurantLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        let distance: CLLocationDistance = userLocation?.distance(from: restaurantLocation) ?? 0
        
        self.init(
            id: googlePlace.id,
            name: googlePlace.displayName.text,
            address: googlePlace.formattedAddress ?? "",
            coordinate: coordinate,
            distance: distance,
            rating: googlePlace.rating,
            reviewCount: googlePlace.userRatingCount,
            priceLevel: GooglePlacesService.convertGooglePriceLevel(googlePlace.priceLevel),
            website: googlePlace.websiteUri,
            phoneNumber: googlePlace.internationalPhoneNumber,
            photoURL: nil, // Will be set separately if needed
            isOpen: googlePlace.currentOpeningHours?.openNow,
            types: googlePlace.types ?? []
        )
    }
}

extension GooglePlacesService {
    static func convertGooglePriceLevel(_ priceLevel: String?) -> Int {
        switch priceLevel {
        case "PRICE_LEVEL_INEXPENSIVE":
            return 1
        case "PRICE_LEVEL_MODERATE":
            return 2
        case "PRICE_LEVEL_EXPENSIVE":
            return 3
        case "PRICE_LEVEL_VERY_EXPENSIVE":
            return 4
        default:
            return 0
        }
    }
} 