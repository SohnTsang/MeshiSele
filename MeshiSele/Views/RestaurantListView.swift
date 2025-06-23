import SwiftUI
import MapKit

struct RestaurantListView: View {
    let restaurants: [Restaurant]
    @StateObject private var locationManager = LocationManager.shared
    @State private var sortOption: RestaurantSortOption = .distance
    @State private var showingMapView = false
    @State private var showingLocationPermissionAlert = false
    @State private var locationRetryCount = 0
    @State private var currentAddress: String? = nil
    @State private var isLoadingAddress = false
    
    // Pagination state
    @State private var displayedRestaurants: [Restaurant] = []
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    private let restaurantsPerPage = 10
    private let maxLocationRetries = 3
    
    // Theme colors
    private let themeOrange = Color(red: 0.96, green: 0.70, blue: 0.42) // #f6b26b
    private let themeTeal = Color(red: 0.42, green: 0.79, blue: 0.72) // #6cc9b7
    
    private var allSortedRestaurants: [Restaurant] {
        // Add safety check to prevent crashes
        let validRestaurants = restaurants.filter { restaurant in
            !restaurant.name.isEmpty && 
            !restaurant.id.isEmpty &&
            restaurant.coordinate.latitude != 0 &&
            restaurant.coordinate.longitude != 0
        }
        
        switch sortOption {
        case .distance:
            return validRestaurants.sorted { 
                ($0.distance ?? Double.greatestFiniteMagnitude) < ($1.distance ?? Double.greatestFiniteMagnitude)
            }
        case .rating:
            return validRestaurants.sorted { 
                ($0.googleRating ?? $0.rating ?? 0) > ($1.googleRating ?? $1.rating ?? 0)
            }
        case .name:
            return validRestaurants.sorted { $0.name < $1.name }
        }
    }
    
    private var hasMoreRestaurants: Bool {
        displayedRestaurants.count < allSortedRestaurants.count
    }
    
    var body: some View {
        mainContentView
            .navigationTitle("お近くのお店")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingMapView = true }) {
                        Image(systemName: "map")
                            .foregroundColor(themeOrange)
                    }
                }
            }
            .sheet(isPresented: $showingMapView) {
                RestaurantMapView(restaurants: restaurants, selectedRestaurant: .constant(nil))
            }
            .alert("位置情報の許可が必要です", isPresented: $showingLocationPermissionAlert) {
                Button("設定") {
                    openLocationSettings()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("お店の検索機能を利用するには位置情報の許可が必要です。設定から位置情報を許可してください。")
            }
            .overlay(congratulationsOverlayView)
            .onAppear(perform: onAppearActions)
            .onChange(of: locationManager.authorizationStatus, perform: onAuthorizationStatusChange)
            .onChange(of: locationManager.currentLocation, perform: onLocationChange)
            .onChange(of: allSortedRestaurants, perform: onRestaurantsChange)
    }
    
    // MARK: - Main Content Views
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            currentLocationView
            headerView
            sortControlsSection
            contentView
        }
    }
    
    private var sortControlsSection: some View {
        sortControlsView
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))
    }
    
    private var contentView: some View {
        Group {
            if restaurants.isEmpty {
                emptyStateView
            } else {
                restaurantListView
            }
        }
    }
    
    private var restaurantListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                restaurantCardsView
                loadMoreButtonView
            }
            .padding(.vertical, 16)
        }
    }
    
    private var restaurantCardsView: some View {
        ForEach(displayedRestaurants) { restaurant in
            RestaurantCard(
                restaurant: restaurant, 
                themeOrange: themeOrange, 
                themeTeal: themeTeal,
                onGoHere: {
                    openInGoogleMaps(restaurant: restaurant)
                    saveRestaurantVisitWithCongratulations(restaurant: restaurant)
                }
            )
            .padding(.horizontal, 16)
        }
    }
    
    private var loadMoreButtonView: some View {
        Group {
            if hasMoreRestaurants {
                Button(action: loadMoreRestaurants) {
                    HStack {
                        if isLoadingMore {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoadingMore ? "読み込み中..." : "さらに表示する (\(allSortedRestaurants.count - displayedRestaurants.count)件)")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeOrange)
                    .cornerRadius(8)
                }
                .disabled(isLoadingMore)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
    
    private var congratulationsOverlayView: some View {
        Group {
            if showingCongratulationsOverlay {
                CongratulationsOverlay(
                    restaurant: selectedRestaurantForHistory,
                    isShowing: $showingCongratulationsOverlay
                )
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func onAppearActions() {
        checkLocationPermission()
        startLocationRetryTimer()
        resetPagination()
        
        if let location = locationManager.currentLocation {
            print("📍 View appeared with existing location, starting reverse geocoding...")
            reverseGeocodeLocation(location)
        }
    }
    
    private func onAuthorizationStatusChange(_ status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationRetryCount = 0
            locationManager.startLocationUpdates()
        }
    }
    
    private func onLocationChange(_ location: CLLocation?) {
        if let location = location {
            print("📍 Location updated, starting reverse geocoding...")
            reverseGeocodeLocation(location)
        } else {
            currentAddress = nil
        }
    }
    
    private func onRestaurantsChange(_ newRestaurants: [Restaurant]) {
        resetPagination()
    }
    
    // MARK: - Pagination Methods
    
    private func resetPagination() {
        currentPage = 0
        displayedRestaurants = Array(allSortedRestaurants.prefix(restaurantsPerPage))
    }
    
    private func loadMoreRestaurants() {
        guard !isLoadingMore && hasMoreRestaurants else { return }
        
        isLoadingMore = true
        
        // Simulate loading delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let startIndex = (currentPage + 1) * restaurantsPerPage
            let endIndex = min(startIndex + restaurantsPerPage, allSortedRestaurants.count)
            
            if startIndex < allSortedRestaurants.count {
                let newRestaurants = Array(allSortedRestaurants[startIndex..<endIndex])
                displayedRestaurants.append(contentsOf: newRestaurants)
                currentPage += 1
            }
            
            isLoadingMore = false
        }
    }
    
    // MARK: - Congratulations Overlay
    
    @State private var showingCongratulationsOverlay = false
    @State private var selectedRestaurantForHistory: Restaurant?
    
    private func saveRestaurantVisitWithCongratulations(restaurant: Restaurant) {
        selectedRestaurantForHistory = restaurant
        showingCongratulationsOverlay = true
        saveRestaurantVisit(restaurant: restaurant)
    }
    
    private var currentLocationView: some View {
        HStack {
            Image(systemName: locationStatusIcon)
                .font(.caption)
                .foregroundColor(locationStatusColor)
            
            if let location = locationManager.currentLocation {
                HStack(spacing: 4) {
                    if isLoadingAddress {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("現在地を取得中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let address = currentAddress {
                        Text("現在地: \(address)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("現在地: \(formatCoordinate(location.coordinate))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                Text("位置情報の利用が許可されていません")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if locationManager.authorizationStatus == .notDetermined {
                VStack(alignment: .leading, spacing: 4) {
                    Text("位置情報の許可を求めています...")
                        .font(.caption)
                        .foregroundColor(.orange)
                    if !restaurants.isEmpty {
                        Text("※ 東京周辺のお店を表示中")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            } else if let errorMessage = locationManager.locationError {
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    if !restaurants.isEmpty {
                        Text("※ 東京周辺のお店を表示中")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                Text("位置情報を取得中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    if locationRetryCount > 0 {
                        Text("(\(locationRetryCount)/\(maxLocationRetries))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if !restaurants.isEmpty && locationRetryCount > 1 {
                        Text("※ 東京周辺のお店を表示中")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Manual retry button when location fails
            if locationManager.currentLocation == nil && locationManager.isLocationPermissionGranted {
                Button(action: {
                    retryLocationFetch()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(themeTeal)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(locationStatusBackgroundColor)
    }
    
    private var locationStatusIcon: String {
        if locationManager.currentLocation != nil {
            return "location.fill"
        } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            return "location.slash"
        } else if locationManager.locationError != nil {
            return "exclamationmark.triangle"
        } else {
            return "location"
        }
    }
    
    private var locationStatusColor: Color {
        if locationManager.currentLocation != nil {
            return themeTeal
        } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            return .red
        } else if locationManager.locationError != nil {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var locationStatusBackgroundColor: Color {
        if locationManager.currentLocation != nil {
            return themeTeal.opacity(0.05)
        } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            return Color.red.opacity(0.05)
        } else if locationManager.locationError != nil {
            return Color.orange.opacity(0.05)
        } else {
            return Color.gray.opacity(0.05)
        }
    }
    
    private func startLocationRetryTimer() {
        // Only retry if permission is granted but location is not available
        guard locationManager.isLocationPermissionGranted && locationManager.currentLocation == nil else {
            return
        }
        
        // Start a timer to retry location fetching
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            if locationManager.currentLocation == nil && locationRetryCount < maxLocationRetries {
                retryLocationFetch()
            }
        }
    }
    
    private func retryLocationFetch() {
        guard locationRetryCount < maxLocationRetries else { return }
        locationRetryCount += 1
        
        // Clear current address when retrying
        currentAddress = nil
        isLoadingAddress = false
        
        print("📍 RestaurantListView: Retrying location fetch (\(locationRetryCount)/\(maxLocationRetries))")
        locationManager.requestOneTimeLocation()
        
        // Schedule next retry if this one fails
        if locationRetryCount < maxLocationRetries {
            Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
                if locationManager.currentLocation == nil {
                    retryLocationFetch()
                }
            }
        }
    }
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation) {
        isLoadingAddress = true
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoadingAddress = false
                
                if let error = error {
                    print("❌ Reverse geocoding failed: \(error.localizedDescription)")
                    currentAddress = nil
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("⚠️ No placemark found")
                    currentAddress = nil
                    return
                }
                
                // Build a detailed Japanese address
                var addressComponents: [String] = []
                
                // Add prefecture/state (都道府県)
                if let administrativeArea = placemark.administrativeArea {
                    addressComponents.append(administrativeArea)
                }
                
                // Add city/ward (市区町村)
                if let locality = placemark.locality {
                    addressComponents.append(locality)
                }
                
                // Add sublocality (区内の地域)
                if let subLocality = placemark.subLocality {
                    addressComponents.append(subLocality)
                }
                
                // Add thoroughfare (通り名/丁目) - this often contains chōme information
                if let thoroughfare = placemark.thoroughfare {
                    addressComponents.append(thoroughfare)
                }
                
                // Add subThoroughfare (番地) if available and not too long
                if let subThoroughfare = placemark.subThoroughfare, subThoroughfare.count <= 10 {
                    addressComponents.append(subThoroughfare)
                }
                
                // If we have detailed info, use it; otherwise fallback to basic info
                if !addressComponents.isEmpty {
                    currentAddress = addressComponents.joined(separator: " ")
                } else if let name = placemark.name {
                    currentAddress = name
                } else {
                    currentAddress = nil
                }
                
                print("🏠 Address components: prefecture=\(placemark.administrativeArea ?? "nil"), locality=\(placemark.locality ?? "nil"), subLocality=\(placemark.subLocality ?? "nil"), thoroughfare=\(placemark.thoroughfare ?? "nil"), subThoroughfare=\(placemark.subThoroughfare ?? "nil")")
                
                print("✅ Reverse geocoded address: \(currentAddress ?? "nil")")
            }
        }
    }
    
    private func checkLocationPermission() {
        if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
            showingLocationPermissionAlert = true
        } else if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestLocationPermission()
        } else if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startLocationUpdates()
        }
    }
    
    private func openLocationSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func openInGoogleMaps(restaurant: Restaurant) {
        let latitude = restaurant.coordinate.latitude
        let longitude = restaurant.coordinate.longitude
        let restaurantAddress = restaurant.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try Google Maps app first with address search
        if let googleMapsURL = URL(string: "comgooglemaps://?q=\(restaurantAddress)&center=\(latitude),\(longitude)&zoom=15"),
           UIApplication.shared.canOpenURL(googleMapsURL) {
            print("🗺️ Opening in Google Maps app with address: \(restaurant.address)")
            UIApplication.shared.open(googleMapsURL)
        } else if let googleMapsWebURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(restaurantAddress)&center=\(latitude),\(longitude)") {
            // Fallback to Google Maps web if app is not installed
            print("🗺️ Opening Google Maps in web browser with address: \(restaurant.address)")
            UIApplication.shared.open(googleMapsWebURL)
        } else {
            // Final fallback to Apple Maps
            print("🗺️ Fallback to Apple Maps")
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: restaurant.coordinate.clCoordinate))
            mapItem.name = restaurant.name
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
        }
    }
    
    private func saveRestaurantVisit(restaurant: Restaurant) {
        // Save restaurant visit to history as "decided"
        let historyEntry = HistoryEntry(
            mealMode: "eatOut",
                                dietFilter: "all",
            cuisine: restaurant.cuisine ?? "restaurant",
            isSurprise: false,
            specifiedIngredients: [],
            excludedIngredients: [],
            servingsCount: 1,
            budgetRange: "noLimit",
            cookTimeConstraint: "noLimit",
            resultType: "restaurant",
            resultId: restaurant.id,
            resultName: restaurant.name,
            isDecided: true
        )
        
        // Save to Firebase
        guard let userId = AuthService.shared.currentUser?.id else { return }
        FirebaseService.shared.saveHistoryEntry(historyEntry, userId: userId) { error in
            if let error = error {
                print("❌ Failed to save restaurant visit: \(error)")
            } else {
                print("✅ Restaurant visit saved to history")
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("見つかったお店")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if displayedRestaurants.count < allSortedRestaurants.count {
                    Text("\(displayedRestaurants.count) / \(allSortedRestaurants.count)件を表示中")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(allSortedRestaurants.count)件のお店")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Fun icon
            Image(systemName: "fork.knife.circle.fill")
                .font(.title2)
                .foregroundColor(themeOrange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [themeOrange.opacity(0.1), themeTeal.opacity(0.1)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private var sortControlsView: some View {
        HStack {
            Text("並び替え:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Menu {
                ForEach(RestaurantSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            sortOption = option
                        }
                    }) {
                        Label(option.displayName, systemImage: sortOption == option ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(sortOption.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(themeOrange)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(themeOrange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(themeOrange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [themeOrange.opacity(0.2), themeTeal.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "map.circle")
                    .font(.system(size: 40))
                    .foregroundColor(themeOrange)
            }
            
            VStack(spacing: 12) {
                Text("お近くのお店が見つかりませんでした")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("条件を変更して再度お試しください")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Congratulations Overlay

struct CongratulationsOverlay: View {
    let restaurant: Restaurant?
    @Binding var isShowing: Bool
    
    // Theme colors
    private let themeOrange = Color(red: 0.96, green: 0.70, blue: 0.42)
    private let themeTeal = Color(red: 0.42, green: 0.79, blue: 0.72)
    
    var body: some View {
        if isShowing {
            GeometryReader { geometry in
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                    
                    // Centered content
                    VStack(spacing: min(24, geometry.size.height * 0.03)) {
                        // Success icon with circular orange background
                        ZStack {
                            Circle()
                                .fill(themeOrange)
                                .frame(width: min(80, geometry.size.width * 0.15), height: min(80, geometry.size.width * 0.15))
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: min(40, geometry.size.width * 0.08), weight: .bold))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(isShowing ? 1.2 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isShowing)
                        
                        VStack(spacing: min(12, geometry.size.height * 0.015)) {
                            Text("保存しました！")
                                .font(.system(size: min(24, geometry.size.width * 0.06), weight: .bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            if let restaurant = restaurant {
                                Text(restaurant.name)
                                    .font(.system(size: min(18, geometry.size.width * 0.045), weight: .medium))
                                    .foregroundColor(themeOrange)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                            }
                            
                            Text("履歴から確認できます")
                                .font(.system(size: min(16, geometry.size.width * 0.04)))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Orange button with gradient
                        Button("OK") {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                        .font(.system(size: min(18, geometry.size.width * 0.045), weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: min(200, geometry.size.width * 0.5))
                        .padding(.vertical, min(14, geometry.size.height * 0.02))
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [themeOrange, themeOrange.opacity(0.9)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(min(25, geometry.size.width * 0.06))
                        .shadow(color: themeOrange.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(min(32, geometry.size.width * 0.08))
                    .background(
                        RoundedRectangle(cornerRadius: min(20, geometry.size.width * 0.05))
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: min(20, geometry.size.width * 0.05))
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [themeOrange.opacity(0.3), themeTeal.opacity(0.3)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .padding(.horizontal, min(40, geometry.size.width * 0.1))
                    .scaleEffect(isShowing ? 1.0 : 0.8)
                    .opacity(isShowing ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isShowing)
                }
            }
            .onAppear {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if isShowing {
                        withAnimation(.easeOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
}

struct RestaurantCard: View {
    let restaurant: Restaurant
    let themeOrange: Color
    let themeTeal: Color
    let onGoHere: () -> Void
    
    // Filter out generic "restaurant" category and show meaningful categories
    private var displayCategories: [String] {
        // First, get all possible categories from various sources
        var allCategories: [String] = []
        
        // Prioritize Google restaurant types (most accurate)
        if !restaurant.googleRestaurantTypes.isEmpty {
            let googleCategories = Restaurant.convertGoogleTypesToCategories(restaurant.googleRestaurantTypes)
            allCategories.append(contentsOf: googleCategories)
        }
        
        // Add categories from restaurant.categories
        allCategories.append(contentsOf: restaurant.categories)
        
        // Add cuisine if available
        if let cuisine = restaurant.cuisine, !cuisine.isEmpty {
            allCategories.append(cuisine)
        }
        
        // Filter out generic and meaningless categories
        let genericTerms = [
            "restaurant", "レストラン", "establishment", "food", "place", "business",
            "飲食店", "店舗", "施設", "place of business", "point of interest"
        ]
        
        let filteredCategories = allCategories.filter { category in
            let lowercased = category.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return !lowercased.isEmpty && 
                   !genericTerms.contains(lowercased) &&
                   lowercased.count > 1 // Filter out single character categories
        }.removingDuplicates()
        
        // If we have meaningful categories, use them
        if !filteredCategories.isEmpty {
            return Array(filteredCategories.prefix(3))
        }
        
        // If no meaningful categories found, try to infer from name
        let restaurantName = restaurant.name.lowercased()
        var inferredCategories: [String] = []
        
        // Common Japanese restaurant type keywords
        let typeKeywords = [
            ("ラーメン", "ラーメン"), ("らーめん", "ラーメン"),
            ("寿司", "寿司"), ("すし", "寿司"), ("鮨", "寿司"),
            ("焼肉", "焼肉"), ("焼き肉", "焼肉"),
            ("居酒屋", "居酒屋"), ("いざかや", "居酒屋"),
            ("カフェ", "カフェ"), ("cafe", "カフェ"), ("coffee", "カフェ"),
            ("イタリアン", "イタリアン"), ("italian", "イタリアン"),
            ("フレンチ", "フレンチ"), ("french", "フレンチ"),
            ("中華", "中華"), ("中国", "中華"),
            ("韓国", "韓国料理"), ("korean", "韓国料理"),
            ("和食", "和食"), ("japanese", "和食"),
            ("タイ", "タイ料理"), ("thai", "タイ料理"),
            ("インド", "インド料理"), ("curry", "カレー"),
            ("ピザ", "ピザ"), ("pizza", "ピザ"),
            ("バー", "バー"), ("bar", "バー"),
            ("定食", "定食"), ("弁当", "弁当"),
            ("蕎麦", "蕎麦"), ("そば", "蕎麦"), ("うどん", "うどん"),
            ("天ぷら", "天ぷら"), ("てんぷら", "天ぷら"),
            ("とんかつ", "とんかつ"), ("豚カツ", "とんかつ")
        ]
        
        for (keyword, category) in typeKeywords {
            if restaurantName.contains(keyword) {
                inferredCategories.append(category)
                break // Only add first match
            }
        }
        
        if !inferredCategories.isEmpty {
            return inferredCategories
        }
        
        // Final fallback
        return ["飲食店"]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 16) {
                // Restaurant Image or Icon
                restaurantImageView
                
                // Restaurant Info
                VStack(alignment: .leading, spacing: 8) {
                    // Name and distance
                    HStack {
                        Text(restaurant.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Prominent distance display
                        if let distance = restaurant.distance {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(themeTeal)
                                Text(formatDistance(distance))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(themeTeal)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeTeal.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Address - Show full address without truncation
                    Text(restaurant.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Rating and Price - Enhanced Display
                    HStack(spacing: 16) {
                        // Rating with better design - prioritize Google rating
                        if let googleRating = restaurant.googleRating, googleRating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", googleRating))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                if let reviewCount = restaurant.googleReviewCount {
                                    Text("(\(reviewCount))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                        } else if let rating = restaurant.rating, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            // Show "Rating unavailable" for restaurants without rating
                            HStack(spacing: 4) {
                                Image(systemName: "star")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("評価なし")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Price level with improved display
                        if let priceLevel = restaurant.priceLevel, priceLevel > 0 {
                            HStack(spacing: 2) {
                                ForEach(0..<priceLevel, id: \.self) { _ in
                                    Text("¥")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(themeOrange)
                                }
                                ForEach(priceLevel..<4, id: \.self) { _ in
                                    Text("¥")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.3))
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeOrange.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    
                    // Categories - Show actual categories instead of "restaurant"
                    if !restaurant.categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(displayCategories, id: \.self) { category in
                                    Text(category)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(themeOrange.opacity(0.15))
                                        .foregroundColor(themeOrange)
                                        .cornerRadius(8)
                                }
                                
                                if displayCategories.count > 3 {
                                    Text("+\(displayCategories.count - 3)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    } else if let cuisine = restaurant.cuisine {
                        // Show cuisine if no categories available
                        Text(cuisine)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeOrange.opacity(0.15))
                            .foregroundColor(themeOrange)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            
            // Action buttons
            HStack(spacing: 16) {
                // Maps button
                Button(action: { openInMaps() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.caption)
                        Text("地図")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(themeOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(themeOrange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Details button - Updated to use orange theme
                Button(action: onGoHere) {
                    HStack(spacing: 6) {
                        Text("ここに行く")
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeOrange)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onGoHere()
        }
    }
    
    private var restaurantImageView: some View {
        Group {
            // Prioritize Google photo, fallback to imageURL
            if let googlePhotoURL = restaurant.googlePhotoURL, let url = URL(string: googlePhotoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [themeOrange.opacity(0.3), themeTeal.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let imageURL = restaurant.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [themeOrange.opacity(0.3), themeTeal.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [themeOrange.opacity(0.3), themeTeal.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    
                    Image(systemName: "building.2.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .frame(width: 70, height: 70)
            }
        }
    }
    
    private func openInMaps() {
        // Add safety check for coordinates
        guard restaurant.coordinate.latitude != 0 && restaurant.coordinate.longitude != 0 else {
            print("⚠️ RestaurantCard: Invalid coordinates for restaurant: \(restaurant.name)")
            return
        }
        
        let latitude = restaurant.coordinate.latitude
        let longitude = restaurant.coordinate.longitude
        let restaurantAddress = restaurant.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try Google Maps app first with address search
        if let googleMapsURL = URL(string: "comgooglemaps://?q=\(restaurantAddress)&center=\(latitude),\(longitude)&zoom=15"),
           UIApplication.shared.canOpenURL(googleMapsURL) {
            print("🗺️ RestaurantCard: Opening in Google Maps app with address: \(restaurant.address)")
            UIApplication.shared.open(googleMapsURL)
        } else if let googleMapsWebURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(restaurantAddress)&center=\(latitude),\(longitude)") {
            // Fallback to Google Maps web if app is not installed
            print("🗺️ RestaurantCard: Opening Google Maps in web browser with address: \(restaurant.address)")
            UIApplication.shared.open(googleMapsWebURL)
        } else {
            // Final fallback to Apple Maps
            print("🗺️ RestaurantCard: Fallback to Apple Maps")
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: restaurant.coordinate.clCoordinate))
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        guard distance > 0 else { return "距離不明" }
        
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

struct RestaurantMapView: View {
    let restaurants: [Restaurant]
    @Binding var selectedRestaurant: Restaurant?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            // Map functionality for iOS 15 - simplified
            VStack {
                Text("近くのレストランを地図で表示")
                    .font(.headline)
                    .padding()
                
                List(restaurants) { restaurant in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(restaurant.name)
                            .font(.headline)
                        
                        Text(restaurant.address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("地図で開く") {
                            let coordinate = restaurant.coordinate.clCoordinate
                            let placemark = MKPlacemark(coordinate: coordinate)
                            let mapItem = MKMapItem(placemark: placemark)
                            mapItem.name = restaurant.name
                            mapItem.openInMaps(launchOptions: nil)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        selectedRestaurant = restaurant
                        dismiss()
                    }
                }
            }
            .navigationTitle("マップ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("完了") {
                    dismiss()
                }
            )
        }
    }
}

struct RestaurantListView_Previews: PreviewProvider {
    static var previews: some View {
        RestaurantListView(restaurants: Restaurant.sampleRestaurants)
    }
}

// MARK: - Array Extension for removing duplicates
extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Restaurant {
    static let sampleRestaurants = [
        Restaurant(data: [
            "name": "銀座ラーメン",
            "address": "東京都中央区銀座1-1-1",
            "phoneNumber": "03-1234-5678",
            "rating": 4.2,
            "cuisine": "ラーメン",
            "priceLevel": 2,
            "latitude": 35.6762,
            "longitude": 139.6503,
            "distance": 500,
            "isOpen": true,
            "openingHours": "月-日: 11:00-22:00",
            "placeId": "sample1",
            "categories": ["ラーメン", "中華"],
            "popularityCount": 25,
            "createdAt": Date(),
            "updatedAt": Date()
        ], id: "sample1"),
        Restaurant(data: [
            "name": "イタリアン カフェ",
            "address": "東京都中央区銀座1-2-3",
            "phoneNumber": "03-2345-6789",
            "website": "https://example.com",
            "rating": 4.5,
            "cuisine": "イタリアン",
            "priceLevel": 3,
            "latitude": 35.6763,
            "longitude": 139.6504,
            "distance": 750,
            "isOpen": true,
            "openingHours": "月-日: 10:00-23:00",
            "placeId": "sample2",
            "categories": ["イタリアン", "カフェ"],
            "popularityCount": 18,
            "createdAt": Date(),
            "updatedAt": Date()
        ], id: "sample2")
    ]
} 