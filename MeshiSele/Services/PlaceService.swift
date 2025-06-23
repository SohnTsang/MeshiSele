import Foundation
import MapKit
import CoreLocation
import FirebaseFirestore

class PlaceService: ObservableObject {
    static let shared = PlaceService()
    
    // Thread safety
    private let searchQueue = DispatchQueue(label: "com.meshisele.placeservice.search", qos: .userInitiated)
    private let db = Firestore.firestore()
    
    // Keep track of active searches to prevent memory issues
    private var activeSearches: Set<UUID> = []
    private let activeSearchesLock = NSLock()
    
    private init() {}
    
    func fetchRandomRestaurant(
        dietFilter: String,
        cuisine: String?,
        budget: BudgetOption,
        excludedIngredients: [String],
        completion: @escaping (Restaurant?) -> Void
    ) {
        let searchId = UUID()
        addActiveSearch(searchId)
        
        searchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Check if search was cancelled
            guard self.isSearchActive(searchId) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let userLocation = LocationManager.shared.currentLocation else {
                // Use fallback restaurant if no location
                DispatchQueue.main.async { [weak self] in
                    self?.getFallbackRestaurant { restaurant in
                        self?.removeActiveSearch(searchId)
                        completion(restaurant)
                    }
                }
                return
            }
            
            let searchTerm = self.buildSearchTerm(dietFilter: dietFilter, cuisine: cuisine)
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchTerm
            request.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
            
            // Add timeout mechanism with proper memory management
            let timeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isSearchActive(searchId) else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.getFallbackRestaurant { restaurant in
                        self?.removeActiveSearch(searchId)
                        completion(restaurant)
                    }
                }
            }
            
            // Set 6 second timeout for MapKit search
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: timeoutWorkItem)
            
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, _ in
                guard let self = self else { return }
                
                // Cancel timeout if request completes
                timeoutWorkItem.cancel()
                
                // Check if search is still active
                guard self.isSearchActive(searchId) else { return }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // Check for network/connectivity errors
                    if response == nil {
                        self.getFallbackRestaurant { restaurant in
                            self.removeActiveSearch(searchId)
                            completion(restaurant)
                        }
                        return
                    }
                    
                    guard let mapItems = response?.mapItems, !mapItems.isEmpty else {
                        // No MapKit results, use fallback restaurants
                        self.getFallbackRestaurant { restaurant in
                            self.removeActiveSearch(searchId)
                            completion(restaurant)
                        }
                        return
                    }
                    
                    // Filter out restaurants whose names contain excluded ingredients
                    let filtered = mapItems.filter { item in
                        let name = item.name?.lowercased() ?? ""
                        
                        // Check if restaurant name contains any excluded ingredients
                        for excluded in excludedIngredients {
                            if name.contains(excluded.lowercased()) {
                                return false
                            }
                        }
                        return true
                    }
                    
                    let candidates = filtered.isEmpty ? mapItems : filtered
                    
                    // Select random restaurant
                    guard !candidates.isEmpty else {
                        self.getFallbackRestaurant { restaurant in
                            self.removeActiveSearch(searchId)
                            completion(restaurant)
                        }
                        return
                    }
                    
                    let randomIndex = Int.random(in: 0..<candidates.count)
                    let chosen = candidates[randomIndex]
                    let restaurant = Restaurant(mapItem: chosen, userLocation: userLocation)
                    self.removeActiveSearch(searchId)
                    completion(restaurant)
                }
            }
        }
    }
    
    func fetchRandomRestaurantForMeal(
        mealKeywords: String,
        cuisine: String,
        budget: BudgetOption,
        excludedIngredients: [String],
        completion: @escaping (Restaurant?) -> Void
    ) {
        let searchId = UUID()
        addActiveSearch(searchId)
        
        searchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Check if search was cancelled
            guard self.isSearchActive(searchId) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let userLocation = LocationManager.shared.currentLocation else {
                print("🔍 PlaceService: No location available, requesting location permission and using default Tokyo location")
                
                // Request location permission if not granted
                if !LocationManager.shared.isLocationPermissionGranted {
                    print("🔍 PlaceService: Requesting location permission...")
                    LocationManager.shared.requestLocationPermission()
                }
                
                // Use default Tokyo location for search (Shibuya)
                let defaultLocation = CLLocation(latitude: 35.6762, longitude: 139.6503)
                print("🔍 PlaceService: Using default Tokyo location: \(defaultLocation.coordinate)")
                
                // Try multiple search strategies with default location
                let searchTerms = [
                    mealKeywords + " レストラン",
                    mealKeywords + " 店",
                    mealKeywords + " 専門店",
                    mealKeywords,
                    "レストラン " + mealKeywords,
                    "飲食店 " + mealKeywords
                ]
                
                self.trySearchWithTerms(searchTerms, userLocation: defaultLocation, limit: 20, searchId: searchId) { [weak self] mapItems in
                    guard let self = self, self.isSearchActive(searchId) else { return }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        if let mapItems = mapItems, !mapItems.isEmpty {
                            print("🔍 PlaceService: Found \(mapItems.count) results from MapKit with default location")
                            
                            // Filter and convert to Restaurant objects
                            let restaurants = mapItems.prefix(20).compactMap { item -> Restaurant? in
                                let name = item.name?.lowercased() ?? ""
                                
                                // Check if restaurant name contains any excluded ingredients
                                for excluded in excludedIngredients {
                                    if name.contains(excluded.lowercased()) {
                                        print("🔍 PlaceService: Excluding restaurant '\(item.name ?? "")' due to ingredient: \(excluded)")
                                        return nil
                                    }
                                }
                                
                                return Restaurant(mapItem: item, userLocation: defaultLocation)
                            }
                            
                            if !restaurants.isEmpty {
                                print("🔍 PlaceService: Returning \(restaurants.count) filtered restaurants from MapKit (default location)")
                                let randomIndex = Int.random(in: 0..<restaurants.count)
                                self.removeActiveSearch(searchId)
                                completion(restaurants[randomIndex])
                                return
                            }
                        }
                        
                        print("🔍 PlaceService: No MapKit results with default location, using meal-specific fallback restaurants")
                        
                        // Still no results, use meal-specific fallback restaurants
                        let fallbackRestaurants = self.createMealSpecificFallbackRestaurants(for: mealKeywords)
                        let filteredRestaurants = self.filterRestaurantsByCriteria(
                            restaurants: fallbackRestaurants,
                            cuisine: cuisine,
                            budget: budget,
                            excludedIngredients: excludedIngredients
                        )
                        print("🔍 PlaceService: Returning \(filteredRestaurants.count) meal-specific fallback restaurants (no MapKit results)")
                        if !filteredRestaurants.isEmpty {
                            let randomIndex = Int.random(in: 0..<filteredRestaurants.count)
                            self.removeActiveSearch(searchId)
                            completion(filteredRestaurants[randomIndex])
                        } else {
                            self.removeActiveSearch(searchId)
                            completion(nil)
                        }
                    }
                }
                return
            }
            
            let searchTerm = self.buildMealSearchTerm(mealKeywords: mealKeywords, cuisine: cuisine)
            
            print("🔍 PlaceService: Searching for restaurants with term: '\(searchTerm)'")
            print("🔍 PlaceService: Meal keywords: '\(mealKeywords)', Cuisine: '\(cuisine)'")
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchTerm
            request.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
            
            // Add timeout mechanism with proper memory management
            let timeoutWorkItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isSearchActive(searchId) else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.getFallbackRestaurant { restaurant in
                        self?.removeActiveSearch(searchId)
                        completion(restaurant)
                    }
                }
            }
            
            // Set 6 second timeout for MapKit search
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0, execute: timeoutWorkItem)
            
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, _ in
                guard let self = self else { return }
                
                // Cancel timeout if request completes
                timeoutWorkItem.cancel()
                
                // Check if search is still active
                guard self.isSearchActive(searchId) else { return }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // Check for network/connectivity errors
                    if response == nil {
                        self.getFallbackRestaurant { restaurant in
                            self.removeActiveSearch(searchId)
                            completion(restaurant)
                        }
                        return
                    }
                    
                    guard let mapItems = response?.mapItems, !mapItems.isEmpty else {
                        // No MapKit results, use fallback restaurants
                        self.getFallbackRestaurant { restaurant in
                            self.removeActiveSearch(searchId)
                            completion(restaurant)
                        }
                        return
                    }
                    
                    // Filter out restaurants whose names contain excluded ingredients
                    let filtered = mapItems.filter { item in
                        let name = item.name?.lowercased() ?? ""
                        
                        // Check if restaurant name contains any excluded ingredients
                        for excluded in excludedIngredients {
                            if name.contains(excluded.lowercased()) {
                                return false
                            }
                        }
                        return true
                    }
                    
                    let candidates = filtered.isEmpty ? mapItems : filtered
                    
                    // Select random restaurant
                    guard !candidates.isEmpty else {
                        self.getFallbackRestaurant { restaurant in
                            self.removeActiveSearch(searchId)
                            completion(restaurant)
                        }
                        return
                    }
                    
                    let randomIndex = Int.random(in: 0..<candidates.count)
                    let chosen = candidates[randomIndex]
                    let restaurant = Restaurant(mapItem: chosen, userLocation: userLocation)
                    self.removeActiveSearch(searchId)
                    completion(restaurant)
                }
            }
        }
    }
    
    // MARK: - Active Search Management
    
    private func addActiveSearch(_ searchId: UUID) {
        activeSearchesLock.lock()
        activeSearches.insert(searchId)
        activeSearchesLock.unlock()
    }
    
    private func removeActiveSearch(_ searchId: UUID) {
        activeSearchesLock.lock()
        activeSearches.remove(searchId)
        activeSearchesLock.unlock()
    }
    
    private func isSearchActive(_ searchId: UUID) -> Bool {
        activeSearchesLock.lock()
        let isActive = activeSearches.contains(searchId)
        activeSearchesLock.unlock()
        return isActive
    }
    
    // MARK: - Search Term Building
    
    private func buildSearchTerm(dietFilter: String, cuisine: String?) -> String {
        // Build search keywords for MapKit
        var keywords = dietFilter
        
        if let cuisine = cuisine {
            keywords += " " + cuisine
        }
        
        return keywords + " レストラン"
    }
    
    private func buildMealSearchTerm(mealKeywords: String, cuisine: String) -> String {
        // Build search term specifically for a meal type
        return mealKeywords + " レストラン"
    }
    
    // MARK: - Multiple Restaurant Fetching
    
    // Fetch multiple restaurants for restaurant list view
    func fetchRestaurants(
        dietFilter: String,
        cuisine: String?,
        budget: BudgetOption,
        excludedIngredients: [String],
        limit: Int = 20,
        completion: @escaping ([Restaurant]) -> Void
    ) {
        let searchId = UUID()
        addActiveSearch(searchId)
        
        searchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Check if search was cancelled
            guard self.isSearchActive(searchId) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let userLocation = LocationManager.shared.currentLocation else {
                DispatchQueue.main.async { [weak self] in
                    self?.removeActiveSearch(searchId)
                    completion([])
                }
                return
            }
            
            let searchTerm = self.buildSearchTerm(dietFilter: dietFilter, cuisine: cuisine)
            
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchTerm
            request.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 10000, // 10km radius for list view
                longitudinalMeters: 10000
            )
            
            let search = MKLocalSearch(request: request)
            search.start { [weak self] response, _ in
                guard let self = self, self.isSearchActive(searchId) else { return }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    guard let mapItems = response?.mapItems else {
                        self.removeActiveSearch(searchId)
                        completion([])
                        return
                    }
                    
                    // Filter and convert to Restaurant objects
                    let restaurants = mapItems.prefix(limit).compactMap { item -> Restaurant? in
                        let name = item.name?.lowercased() ?? ""
                        
                        // Check if restaurant name contains any excluded ingredients
                        for excluded in excludedIngredients {
                            if name.contains(excluded.lowercased()) {
                                return nil
                            }
                        }
                        
                        return Restaurant(mapItem: item, userLocation: userLocation)
                    }
                    
                    self.removeActiveSearch(searchId)
                    completion(Array(restaurants))
                }
            }
        }
    }
    
    // Fetch multiple restaurants for a specific meal type with fallback
    func fetchRestaurantsForMeal(
        mealKeywords: String,
        cuisine: String,
        budget: BudgetOption,
        excludedIngredients: [String],
        limit: Int = 20,
        completion: @escaping ([Restaurant]) -> Void
    ) {
        print("🔍 PlaceService: fetchRestaurantsForMeal called")
        print("🔍 PlaceService: mealKeywords: '\(mealKeywords)'")
        print("🔍 PlaceService: cuisine: '\(cuisine)'")
        print("🔍 PlaceService: budget: \(budget)")
        print("🔍 PlaceService: excludedIngredients: \(excludedIngredients)")
        
        let searchId = UUID()
        addActiveSearch(searchId)
        
        searchQueue.async { [weak self] in
            guard let self = self else {
                print("🔍 PlaceService: self is nil, returning empty")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Check if search was cancelled
            guard self.isSearchActive(searchId) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            guard let userLocation = LocationManager.shared.currentLocation else {
                print("🔍 PlaceService: No location available, using default Tokyo location for restaurant list")
                
                // Request location permission if not granted
                if !LocationManager.shared.isLocationPermissionGranted {
                    print("🔍 PlaceService: Requesting location permission...")
                    LocationManager.shared.requestLocationPermission()
                }
                
                // Use default Tokyo location for search (Shibuya)
                let defaultLocation = CLLocation(latitude: 35.6762, longitude: 139.6503)
                print("🔍 PlaceService: Using default Tokyo location: \(defaultLocation.coordinate)")
                
                // Try multiple search strategies with default location
                let searchTerms = [
                    mealKeywords + " レストラン",
                    mealKeywords + " 店",
                    mealKeywords + " 専門店",
                    mealKeywords,
                    "レストラン " + mealKeywords,
                    "飲食店 " + mealKeywords
                ]
                
                self.trySearchWithTerms(searchTerms, userLocation: defaultLocation, limit: limit, searchId: searchId) { [weak self] mapItems in
                    guard let self = self, self.isSearchActive(searchId) else { return }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        if let mapItems = mapItems, !mapItems.isEmpty {
                            print("🔍 PlaceService: Found \(mapItems.count) results from MapKit with default location")
                            
                            // Filter and convert to Restaurant objects
                            let restaurants = mapItems.prefix(limit).compactMap { item -> Restaurant? in
                                let name = item.name?.lowercased() ?? ""
                                
                                // Check if restaurant name contains any excluded ingredients
                                for excluded in excludedIngredients {
                                    if name.contains(excluded.lowercased()) {
                                        print("🔍 PlaceService: Excluding restaurant '\(item.name ?? "")' due to ingredient: \(excluded)")
                                        return nil
                                    }
                                }
                                
                                return Restaurant(mapItem: item, userLocation: defaultLocation)
                            }
                            
                            if !restaurants.isEmpty {
                                print("🔍 PlaceService: Returning \(restaurants.count) filtered restaurants from MapKit (default location)")
                                self.removeActiveSearch(searchId)
                                completion(Array(restaurants))
                                return
                            }
                        }
                        
                        print("🔍 PlaceService: No MapKit results with default location, using meal-specific fallback restaurants")
                        
                        // Still no results, use meal-specific fallback restaurants
                        let fallbackRestaurants = self.createMealSpecificFallbackRestaurants(for: mealKeywords)
                        let filteredRestaurants = self.filterRestaurantsByCriteria(
                            restaurants: fallbackRestaurants,
                            cuisine: cuisine,
                            budget: budget,
                            excludedIngredients: excludedIngredients
                        )
                        print("🔍 PlaceService: Returning \(filteredRestaurants.count) meal-specific fallback restaurants (no MapKit results)")
                        self.removeActiveSearch(searchId)
                        completion(Array(filteredRestaurants.prefix(limit)))
                    }
                }
                return
            }
            
            print("🔍 PlaceService: User location available: \(userLocation.coordinate)")
            
            // Try multiple search strategies with meal-specific terms
            let searchTerms = [
                mealKeywords + " レストラン",
                mealKeywords + " 店",
                mealKeywords + " 専門店",
                mealKeywords,
                "レストラン " + mealKeywords,
                "飲食店 " + mealKeywords
            ]
            
            self.trySearchWithTerms(searchTerms, userLocation: userLocation, limit: limit, searchId: searchId) { [weak self] mapItems in
                guard let self = self, self.isSearchActive(searchId) else { return }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    if let mapItems = mapItems, !mapItems.isEmpty {
                        print("🔍 PlaceService: Found \(mapItems.count) results from MapKit")
                        
                        // Filter and convert to Restaurant objects
                        let restaurants = mapItems.prefix(limit).compactMap { item -> Restaurant? in
                            let name = item.name?.lowercased() ?? ""
                            
                            // Check if restaurant name contains any excluded ingredients
                            for excluded in excludedIngredients {
                                if name.contains(excluded.lowercased()) {
                                    print("🔍 PlaceService: Excluding restaurant '\(item.name ?? "")' due to ingredient: \(excluded)")
                                    return nil
                                }
                            }
                            
                            return Restaurant(mapItem: item, userLocation: userLocation)
                        }
                        
                        if !restaurants.isEmpty {
                            print("🔍 PlaceService: Returning \(restaurants.count) filtered restaurants from MapKit")
                            self.removeActiveSearch(searchId)
                            completion(Array(restaurants))
                            return
                        }
                    }
                    
                    print("🔍 PlaceService: No MapKit results, using meal-specific fallback restaurants")
                    
                    // No results from MapKit search, use meal-specific fallback restaurants
                    let fallbackRestaurants = self.createMealSpecificFallbackRestaurants(for: mealKeywords)
                    let filteredRestaurants = self.filterRestaurantsByCriteria(
                        restaurants: fallbackRestaurants,
                        cuisine: cuisine,
                        budget: budget,
                        excludedIngredients: excludedIngredients
                    )
                    print("🔍 PlaceService: Returning \(filteredRestaurants.count) meal-specific fallback restaurants")
                    self.removeActiveSearch(searchId)
                    completion(Array(filteredRestaurants.prefix(limit)))
                }
            }
        }
    }
    
    // Helper function to try multiple search terms with proper memory management
    private func trySearchWithTerms(
        _ searchTerms: [String],
        userLocation: CLLocation,
        limit: Int,
        searchId: UUID,
        completion: @escaping ([MKMapItem]?) -> Void
    ) {
        guard !searchTerms.isEmpty, isSearchActive(searchId) else {
            completion(nil)
            return
        }
        
        let searchTerm = searchTerms[0]
        let remainingTerms = Array(searchTerms.dropFirst())
        
        print("🔍 PlaceService: Trying search term: '\(searchTerm)'")
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchTerm
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: 10000, // 10km radius
            longitudinalMeters: 10000
        )
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            guard let self = self, self.isSearchActive(searchId) else { return }
            
            if let mapItems = response?.mapItems, !mapItems.isEmpty {
                print("🔍 PlaceService: Search term '\(searchTerm)' found \(mapItems.count) results")
                completion(mapItems)
            } else {
                print("🔍 PlaceService: Search term '\(searchTerm)' returned no results")
                
                // Try next search term
                if !remainingTerms.isEmpty {
                    self.trySearchWithTerms(remainingTerms, userLocation: userLocation, limit: limit, searchId: searchId, completion: completion)
                } else {
                    print("🔍 PlaceService: All search terms exhausted")
                    completion(nil)
                }
            }
        }
    }
    
    // Helper function to filter restaurants by criteria
    private func filterRestaurantsByCriteria(
        restaurants: [Restaurant],
        cuisine: String,
        budget: BudgetOption,
        excludedIngredients: [String]
    ) -> [Restaurant] {
        print("🔍 PlaceService: Filtering \(restaurants.count) restaurants")
        print("🔍 PlaceService: Filter criteria - cuisine: '\(cuisine)', budget: \(budget)")
        
        // First try strict filtering
        let strictFiltered = restaurants.filter { restaurant in
            // Convert cuisine raw value to display name for comparison
            let cuisineDisplayName = CuisineOption.allCases.first { $0.rawValue == cuisine }?.displayName ?? cuisine
            
            // Check cuisine match (flexible matching)
            let matchesCuisine: Bool
            if cuisineDisplayName == "すべて" {
                // "すべて" means show all cuisines
                matchesCuisine = true
            } else if cuisineDisplayName == "その他" {
                // "その他" means exclude main cuisine categories
                let mainCuisines = ["和食", "洋食", "中華", "イタリアン", "韓国", "フレンチ"]
                matchesCuisine = !restaurant.categories.contains { category in
                    mainCuisines.contains { mainCuisine in
                        category.contains(mainCuisine) || mainCuisine.contains(category)
                    }
                }
            } else {
                matchesCuisine = restaurant.categories.contains { category in
                category.contains(cuisineDisplayName) || cuisineDisplayName.contains(category)
            } || restaurant.cuisine?.contains(cuisineDisplayName) == true
            }
            
            // Check budget match
            let matchesBudget: Bool
            if budget == .noLimit {
                matchesBudget = true
            } else {
                let restaurantPrice = restaurant.priceLevel ?? 1
                                    switch budget {
                    case .under500:
                        matchesBudget = restaurantPrice <= 1
                    case .between500_1000:
                        matchesBudget = restaurantPrice == 2
                    case .between1000_1500:
                        matchesBudget = restaurantPrice == 3
                    case .custom(_, let max):
                        // Map custom budget to price levels
                        let expectedPriceLevel: Int
                        if max <= 500 {
                            expectedPriceLevel = 1
                        } else if max <= 1500 {
                            expectedPriceLevel = 2
                        } else if max <= 3000 {
                            expectedPriceLevel = 3
                        } else {
                            expectedPriceLevel = 4
                        }
                        matchesBudget = restaurantPrice <= expectedPriceLevel
                    case .noLimit:
                        matchesBudget = true
                    }
            }
            
            // Check excluded ingredients
            let matchesExcludedIngredients = !restaurant.categories.contains { category in
                excludedIngredients.contains { ingredient in
                    category.lowercased().contains(ingredient.lowercased())
                }
            }
            
            return matchesCuisine && matchesBudget && matchesExcludedIngredients
        }
        
        print("🔍 PlaceService: Strict filtering returned \(strictFiltered.count) restaurants")
        
        // If strict filtering returns enough results, use them
        if strictFiltered.count >= 3 {
            return strictFiltered
        }
        
        // If not enough results, try more lenient filtering (ignore cuisine)
        let lenientFiltered = restaurants.filter { restaurant in
            // Check budget match
            let matchesBudget: Bool
            if budget == .noLimit {
                matchesBudget = true
            } else {
                let restaurantPrice = restaurant.priceLevel ?? 1
                                        switch budget {
                        case .under500:
                            matchesBudget = restaurantPrice <= 2 // More lenient
                        case .between500_1000:
                            matchesBudget = restaurantPrice <= 3 // More lenient
                        case .between1000_1500:
                            matchesBudget = restaurantPrice <= 4 // More lenient
                        case .custom(_, let max):
                            // More lenient custom budget mapping
                            let maxExpectedPriceLevel: Int
                            if max <= 750 {
                                maxExpectedPriceLevel = 2
                            } else if max <= 2000 {
                                maxExpectedPriceLevel = 3
                            } else {
                                maxExpectedPriceLevel = 4
                            }
                            matchesBudget = restaurantPrice <= maxExpectedPriceLevel
                        case .noLimit:
                            matchesBudget = true
                        }
            }
            
            // Check excluded ingredients (keep this strict)
            let matchesExcludedIngredients = !restaurant.categories.contains { category in
                excludedIngredients.contains { ingredient in
                    category.lowercased().contains(ingredient.lowercased())
                }
            }
            
            return matchesBudget && matchesExcludedIngredients
        }
        
        print("🔍 PlaceService: Lenient filtering returned \(lenientFiltered.count) restaurants")
        
        // If lenient filtering returns results, use them
        if !lenientFiltered.isEmpty {
            return lenientFiltered
        }
        
        // If still no results, return all restaurants (ignore all filters except excluded ingredients)
        let finalFiltered = restaurants.filter { restaurant in
            // Only check excluded ingredients
            let matchesExcludedIngredients = !restaurant.categories.contains { category in
                excludedIngredients.contains { ingredient in
                    category.lowercased().contains(ingredient.lowercased())
                }
            }
            return matchesExcludedIngredients
        }
        
        print("🔍 PlaceService: Final filtering returned \(finalFiltered.count) restaurants")
        
        // If even that fails, return all restaurants
        return finalFiltered.isEmpty ? restaurants : finalFiltered
    }
    
    // Search restaurants by name
    func searchRestaurants(query: String, completion: @escaping ([Restaurant]) -> Void) {
        let searchId = UUID()
        addActiveSearch(searchId)
        
        guard let userLocation = LocationManager.shared.currentLocation else {
            removeActiveSearch(searchId)
            completion([])
            return
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query + " レストラン"
        request.region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: 10000, // Larger radius for search
            longitudinalMeters: 10000
        )
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            guard let self = self, self.isSearchActive(searchId) else { return }
            
            guard let mapItems = response?.mapItems else {
                self.removeActiveSearch(searchId)
                completion([])
                return
            }
            
            let restaurants = mapItems.map { item in
                Restaurant(mapItem: item, userLocation: userLocation)
            }
            
            self.removeActiveSearch(searchId)
            completion(restaurants)
        }
    }
    
    // Get restaurant details by coordinate (for saved restaurants)
    func getRestaurantDetails(
        coordinate: CLLocationCoordinate2D,
        completion: @escaping (Restaurant?) -> Void
    ) {
        let searchId = UUID()
        addActiveSearch(searchId)
        
        guard let userLocation = LocationManager.shared.currentLocation else {
            removeActiveSearch(searchId)
            completion(nil)
            return
        }
        
        let request = MKLocalSearch.Request()
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 100, // Very small radius to find the specific place
            longitudinalMeters: 100
        )
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, _ in
            guard let self = self, self.isSearchActive(searchId) else { return }
            
            guard let mapItems = response?.mapItems,
                  let firstItem = mapItems.first else {
                self.removeActiveSearch(searchId)
                completion(nil)
                return
            }
            
            let restaurant = Restaurant(mapItem: firstItem, userLocation: userLocation)
            self.removeActiveSearch(searchId)
            completion(restaurant)
        }
    }
    
    private func getFallbackRestaurant(completion: @escaping (Restaurant?) -> Void) {
        // Add artificial delay to ensure spinner shows for minimum duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            let fallbackRestaurants = self.createFallbackJapaneseRestaurants()
            let randomIndex = Int.random(in: 0..<fallbackRestaurants.count)
            completion(fallbackRestaurants[randomIndex])
        }
    }
    
    private func createFallbackJapaneseRestaurants() -> [Restaurant] {
        return [
            Restaurant(data: [
                "name": "らーめん 一番",
                "address": "東京都新宿区西新宿1-1-1",
                "phoneNumber": "03-1234-5678",
                "cuisine": "ラーメン",
                "category": "ラーメン",
                "priceLevel": 1,
                "rating": 4.2,
                "latitude": 35.6762 + Double.random(in: -0.01...0.01),
                "longitude": 139.7639 + Double.random(in: -0.01...0.01),
                "categories": ["ラーメン", "麺類"],
                "openingHours": "11:00-22:00",
                "estimatedBudget": 900,
                "popularityCount": 234
            ], id: "fallback_restaurant_1"),
            
            Restaurant(data: [
                "name": "すし処 まぐろ",
                "address": "東京都渋谷区道玄坂2-2-2",
                "phoneNumber": "03-9876-5432",
                "cuisine": "寿司",
                "category": "寿司",
                "priceLevel": 3,
                "rating": 4.5,
                "latitude": 35.6580 + Double.random(in: -0.01...0.01),
                "longitude": 139.7016 + Double.random(in: -0.01...0.01),
                "categories": ["寿司", "和食"],
                "openingHours": "17:00-23:00",
                "estimatedBudget": 4500,
                "popularityCount": 187
            ], id: "fallback_restaurant_2"),
            
            Restaurant(data: [
                "name": "焼肉 牛角",
                "address": "東京都品川区大崎3-3-3",
                "phoneNumber": "03-5555-1234",
                "cuisine": "焼肉",
                "category": "焼肉",
                "priceLevel": 2,
                "rating": 4.0,
                "latitude": 35.6197 + Double.random(in: -0.01...0.01),
                "longitude": 139.7280 + Double.random(in: -0.01...0.01),
                "categories": ["焼肉", "韓国料理"],
                "openingHours": "17:00-24:00",
                "estimatedBudget": 2800,
                "popularityCount": 156
            ], id: "fallback_restaurant_3"),
            
            Restaurant(data: [
                "name": "カフェ サクラ",
                "address": "東京都中央区銀座4-4-4",
                "phoneNumber": "03-7777-8888",
                "cuisine": "カフェ",
                "category": "カフェ",
                "priceLevel": 1,
                "rating": 4.1,
                "latitude": 35.6762 + Double.random(in: -0.01...0.01),
                "longitude": 139.7669 + Double.random(in: -0.01...0.01),
                "categories": ["カフェ", "軽食"],
                "openingHours": "8:00-20:00",
                "estimatedBudget": 1200,
                "popularityCount": 89
            ], id: "fallback_restaurant_4"),
            
            Restaurant(data: [
                "name": "天ぷら 海老蔵",
                "address": "東京都港区六本木5-5-5",
                "phoneNumber": "03-3333-9999",
                "cuisine": "天ぷら",
                "category": "天ぷら",
                "priceLevel": 3,
                "rating": 4.7,
                "latitude": 35.6627 + Double.random(in: -0.01...0.01),
                "longitude": 139.7314 + Double.random(in: -0.01...0.01),
                "categories": ["天ぷら", "和食"],
                "openingHours": "12:00-15:00, 18:00-22:00",
                "estimatedBudget": 6500,
                "popularityCount": 67
            ], id: "fallback_restaurant_5")
        ]
    }
    
    func fetchRandomRestaurantOffline(
        dietFilter: String,
        cuisine: String?,
        budget: BudgetOption,
        excludedIngredients: [String],
        completion: @escaping (Restaurant?) -> Void
    ) {
        // Fetch restaurants from local database (Firestore)
        db.collection("restaurants")
            .whereField("isOfflineAvailable", isEqualTo: true)  // Only fetch restaurants marked as available offline
            .getDocuments { snapshot, error in
                
                if error != nil {
                    completion(nil)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(nil)
                    return
                }
                
                // Convert documents to Restaurant objects
                let restaurants = documents.compactMap { document -> Restaurant? in
                    let data = document.data()
                    return Restaurant(data: data)
                }
                
                // Filter restaurants based on criteria
                let filteredRestaurants = restaurants.filter { restaurant in
                    // Apply filters
                    let matchesDiet = restaurant.categories.contains(dietFilter) || dietFilter == "all"
                    let matchesCuisine = cuisine == nil || restaurant.cuisine == cuisine
                    
                    // Budget matching logic
                    let matchesBudget: Bool
                    if budget == .noLimit {
                        matchesBudget = true
                    } else {
                        // Check if restaurant price level is within budget range
                        // Safely unwrap optional priceLevel, default to 1 if nil
                        let restaurantPrice = restaurant.priceLevel ?? 1
                        switch budget {
                        case .under500:
                            matchesBudget = restaurantPrice <= 1
                        case .between500_1000:
                            matchesBudget = restaurantPrice == 2
                        case .between1000_1500:
                            matchesBudget = restaurantPrice == 3
                        case .custom(_, let max):
                            // Map custom budget to price levels (rough approximation)
                            let expectedPriceLevel: Int
                            if max <= 500 {
                                expectedPriceLevel = 1
                            } else if max <= 1500 {
                                expectedPriceLevel = 2
                            } else if max <= 3000 {
                                expectedPriceLevel = 3
                            } else {
                                expectedPriceLevel = 4
                            }
                            matchesBudget = restaurantPrice <= expectedPriceLevel
                        case .noLimit:
                            matchesBudget = true
                        }
                    }
                    
                    let matchesExcludedIngredients = !restaurant.categories.contains { category in
                        excludedIngredients.contains { ingredient in
                            category.lowercased().contains(ingredient.lowercased())
                        }
                    }
                    
                    return matchesDiet && matchesCuisine && matchesBudget && matchesExcludedIngredients
                }
                
                // Select a random restaurant from filtered results
                if let randomRestaurant = filteredRestaurants.randomElement() {
                    completion(randomRestaurant)
                } else {
                    completion(nil)
                }
            }
    }
    
    private func createMealSpecificFallbackRestaurants(for mealKeywords: String) -> [Restaurant] {
        print("🔍 PlaceService: Creating meal-specific fallback restaurants for: '\(mealKeywords)'")
        
        let mealLower = mealKeywords.lowercased()
        
        // Create restaurants based on meal type
        var restaurants: [Restaurant] = []
        
        if mealLower.contains("焼肉") || mealLower.contains("yakiniku") || mealLower.contains("bbq") {
            restaurants = [
                Restaurant(data: [
                    "id": "yakiniku_1",
                    "name": "焼肉王",
                    "address": "東京都渋谷区",
                    "phoneNumber": "03-1234-5678",
                    "rating": 4.2,
                    "priceLevel": 3,
                    "categories": ["焼肉", "和食", "BBQ"],
                    "cuisine": "washoku",
                    "latitude": 35.6762,
                    "longitude": 139.6503,
                    "distance": 500.0
                ], id: "yakiniku_1"),
                Restaurant(data: [
                    "id": "yakiniku_2",
                    "name": "牛角",
                    "address": "東京都新宿区",
                    "phoneNumber": "03-2345-6789",
                    "rating": 4.0,
                    "priceLevel": 2,
                    "categories": ["焼肉", "和食"],
                    "cuisine": "washoku",
                    "latitude": 35.6896,
                    "longitude": 139.6917,
                    "distance": 800.0
                ], id: "yakiniku_2"),
                Restaurant(data: [
                    "id": "yakiniku_3",
                    "name": "焼肉ライク",
                    "address": "東京都港区",
                    "phoneNumber": "03-3456-7890",
                    "rating": 3.8,
                    "priceLevel": 2,
                    "categories": ["焼肉", "一人焼肉"],
                    "cuisine": "washoku",
                    "latitude": 35.6584,
                    "longitude": 139.7234,
                    "distance": 1200.0
                ], id: "yakiniku_3")
            ]
        } else if mealLower.contains("ラーメン") || mealLower.contains("ramen") {
            restaurants = [
                Restaurant(data: [
                    "id": "ramen_1",
                    "name": "一蘭",
                    "address": "東京都渋谷区",
                    "phoneNumber": "03-1111-2222",
                    "rating": 4.1,
                    "priceLevel": 2,
                    "categories": ["ラーメン", "とんこつ"],
                    "cuisine": "washoku",
                    "latitude": 35.6762,
                    "longitude": 139.6503,
                    "distance": 300.0
                ], id: "ramen_1"),
                Restaurant(data: [
                    "id": "ramen_2",
                    "name": "麺屋武蔵",
                    "address": "東京都新宿区",
                    "phoneNumber": "03-2222-3333",
                    "rating": 4.3,
                    "priceLevel": 2,
                    "categories": ["ラーメン", "つけ麺"],
                    "cuisine": "washoku",
                    "latitude": 35.6896,
                    "longitude": 139.6917,
                    "distance": 600.0
                ], id: "ramen_2")
            ]
        } else if mealLower.contains("寿司") || mealLower.contains("sushi") {
            restaurants = [
                Restaurant(data: [
                    "id": "sushi_1",
                    "name": "すし銀座",
                    "address": "東京都中央区銀座",
                    "phoneNumber": "03-3333-4444",
                    "rating": 4.5,
                    "priceLevel": 4,
                    "categories": ["寿司", "和食", "高級"],
                    "cuisine": "washoku",
                    "latitude": 35.6719,
                    "longitude": 139.7648,
                    "distance": 1000.0
                ], id: "sushi_1"),
                Restaurant(data: [
                    "id": "sushi_2",
                    "name": "回転寿司スシロー",
                    "address": "東京都渋谷区",
                    "phoneNumber": "03-4444-5555",
                    "rating": 3.9,
                    "priceLevel": 1,
                    "categories": ["回転寿司", "寿司"],
                    "cuisine": "washoku",
                    "latitude": 35.6762,
                    "longitude": 139.6503,
                    "distance": 400.0
                ], id: "sushi_2")
            ]
        } else if mealLower.contains("カレー") || mealLower.contains("curry") {
            restaurants = [
                Restaurant(data: [
                    "id": "curry_1",
                    "name": "CoCo壱番屋",
                    "address": "東京都渋谷区",
                    "phoneNumber": "03-5555-6666",
                    "rating": 3.7,
                    "priceLevel": 2,
                    "categories": ["カレー", "洋食"],
                    "cuisine": "yoshoku",
                    "latitude": 35.6762,
                    "longitude": 139.6503,
                    "distance": 350.0
                ], id: "curry_1"),
                Restaurant(data: [
                    "id": "curry_2",
                    "name": "インドカレー ガンジス",
                    "address": "東京都新宿区",
                    "phoneNumber": "03-6666-7777",
                    "rating": 4.2,
                    "priceLevel": 2,
                    "categories": ["インドカレー", "カレー"],
                    "cuisine": "other",
                    "latitude": 35.6896,
                    "longitude": 139.6917,
                    "distance": 700.0
                ], id: "curry_2")
            ]
        } else if mealLower.contains("居酒屋") || mealLower.contains("izakaya") {
            restaurants = [
                Restaurant(data: [
                    "id": "izakaya_1",
                    "name": "鳥貴族",
                    "address": "東京都渋谷区",
                    "phoneNumber": "03-7777-8888",
                    "rating": 3.8,
                    "priceLevel": 2,
                    "categories": ["居酒屋", "焼き鳥", "和食"],
                    "cuisine": "washoku",
                    "latitude": 35.6762,
                    "longitude": 139.6503,
                    "distance": 450.0
                ], id: "izakaya_1"),
                Restaurant(data: [
                    "id": "izakaya_2",
                    "name": "魚民",
                    "address": "東京都新宿区",
                    "phoneNumber": "03-8888-9999",
                    "rating": 3.6,
                    "priceLevel": 2,
                    "categories": ["居酒屋", "海鮮", "和食"],
                    "cuisine": "washoku",
                    "latitude": 35.6896,
                    "longitude": 139.6917,
                    "distance": 650.0
                ], id: "izakaya_2"),
                Restaurant(data: [
                    "id": "izakaya_3",
                    "name": "和民",
                    "address": "東京都港区",
                    "phoneNumber": "03-9999-0000",
                    "rating": 3.5,
                    "priceLevel": 2,
                    "categories": ["居酒屋", "和食"],
                    "cuisine": "washoku",
                    "latitude": 35.6584,
                    "longitude": 139.7234,
                    "distance": 900.0
                ], id: "izakaya_3")
            ]
        } else {
            // Default fallback - use general Japanese restaurants
            restaurants = createFallbackJapaneseRestaurants()
        }
        
        print("🔍 PlaceService: Created \(restaurants.count) meal-specific restaurants")
        return restaurants
    }
}

// Extension for sorting restaurants
extension Array where Element == Restaurant {
    func sortedByDistance() -> [Restaurant] {
        return sorted { ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude) }
    }
    
    func sortedByRating() -> [Restaurant] {
        return sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }
    
    func sortedByName() -> [Restaurant] {
        return sorted { $0.name < $1.name }
    }
} 