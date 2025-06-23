import SwiftUI
import MapKit

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @State private var isBookmarked = false
    @State private var userRating: Double = 0.0
    @State private var showingShareSheet = false
    @State private var showingDirections = false
    @State private var isLoadingRating = false
    @State private var averageRating: Double = 0.0
    @State private var ratingCount: Int = 0
    @State private var isLoadingAverageRating = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Restaurant Header
                restaurantHeaderSection
                
                // Action Buttons
                actionButtonsSection
                
                // Popularity Section
                popularitySection
                
                // Restaurant Info
                restaurantInfoSection
                
                // User Rating Section
                userRatingSection
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBookmarkStatus()
            loadExistingRating()
            loadAverageRating()
        }
        .sheet(isPresented: $showingShareSheet) {
            RestaurantShareSheet(restaurant: restaurant)
        }
        .sheet(isPresented: $showingDirections) {
            DirectionsView(restaurant: restaurant)
        }
    }
    
    private var restaurantHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Restaurant Image
            if let imageURL = restaurant.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "building.2")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Restaurant Name
            Text(restaurant.name)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Rating and Distance
            HStack(spacing: 16) {
                if let rating = restaurant.rating, rating > 0 {
                    HStack(spacing: 4) {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let distance = restaurant.distance {
                    HStack(spacing: 2) {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f km", distance / 1000))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Bookmark Button
            Button(action: {
                toggleBookmark()
            }) {
                HStack {
                    Image(systemName: isBookmarked ? "heart.fill" : "heart")
                        .foregroundColor(isBookmarked ? .red : .secondary)
                    Text(isBookmarked ? NSLocalizedString("favorited", comment: "Favorited") : NSLocalizedString("add_to_favorites", comment: "Add to favorites"))
                        .font(.subheadline)
                        .foregroundColor(isBookmarked ? .red : .primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isBookmarked ? Color.red : Color(.systemGray4), lineWidth: 1)
                )
            }
            
            // Directions Button
            Button(action: {
                getDirections()
            }) {
                HStack {
                    Image(systemName: "arrow.turn.up.right")
                    Text(NSLocalizedString("directions", comment: "Directions"))
                        .font(.subheadline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(20)
            }
            
            Spacer()
            
            // Share Button
            Button(action: {
                showingShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .padding(8)
            }
        }
    }
    
    private var popularitySection: some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundColor(.blue)
                .font(.title3)
            
            Text(String(format: NSLocalizedString("popularity_count", comment: "Popularity count"), restaurant.popularityCount))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(NSLocalizedString("popularity_label", comment: "Popularity label"))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    private var restaurantInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Address
            if !restaurant.address.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("住所", systemImage: "location")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(restaurant.address)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // Phone Number
            if let phoneNumber = restaurant.phoneNumber {
                VStack(alignment: .leading, spacing: 8) {
                    Label("電話番号", systemImage: "phone")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        restaurant.callRestaurant()
                    }) {
                        Text(phoneNumber)
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Website
            if restaurant.website != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Label("ウェブサイト", systemImage: "globe")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        restaurant.openWebsite()
                    }) {
                        Text("ウェブサイトを開く")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Opening Hours
            if let openingHours = restaurant.openingHours {
                VStack(alignment: .leading, spacing: 8) {
                    Label("営業時間", systemImage: "clock")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(openingHours)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
    }
    
    private var userRatingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("このお店を評価")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoadingRating || isLoadingAverageRating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Average Rating Display
            VStack(alignment: .leading, spacing: 8) {
                Text("みんなの評価")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    if ratingCount > 0 {
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
                                    .foregroundColor(star <= Int(averageRating.rounded()) ? .yellow : .gray)
                                    .font(.subheadline)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f", averageRating))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("\(ratingCount)件の評価")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { _ in
                                Image(systemName: "star")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("未評価")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            
                            Text("まだ評価がありません")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ratingCount > 0 ? Color.yellow.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ratingCount > 0 ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // User Rating Section
            VStack(alignment: .leading, spacing: 12) {
                Text("あなたの評価")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(userRating) ? "star.fill" : "star")
                            .foregroundColor(star <= Int(userRating) ? .orange : .gray)
                            .font(.title)
                            .onTapGesture {
                                saveRestaurantRating(Double(star))
                            }
                    }
                }
                
                if userRating > 0 {
                    VStack(spacing: 8) {
                        Text("評価をありがとうございます")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        
                        Text("このお店の評価が保存されました")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray6).opacity(0.3))
        )
    }
    
    private func loadBookmarkStatus() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        let itemId = restaurant.placeId ?? restaurant.id
        
        FirebaseService.shared.isBookmarked(type: "restaurant", itemId: itemId, userId: userId) { isBookmarked in
            DispatchQueue.main.async {
                self.isBookmarked = isBookmarked
            }
        }
    }
    
    private func toggleBookmark() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        let itemId = restaurant.placeId ?? restaurant.id
        
        if isBookmarked {
            FirebaseService.shared.removeBookmark(type: "restaurant", itemId: itemId, userId: userId) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self.isBookmarked = false
                    }
                }
            }
        } else {
            FirebaseService.shared.addBookmark(type: "restaurant", itemId: itemId, userId: userId) { error in
                DispatchQueue.main.async {
                    if error == nil {
                        self.isBookmarked = true
                    }
                }
            }
        }
    }
    
    private func openInMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: restaurant.coordinate.latitude, longitude: restaurant.coordinate.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        mapItem.openInMaps()
    }
    
    private func getDirections() {
        let coordinate = CLLocationCoordinate2D(latitude: restaurant.coordinate.latitude, longitude: restaurant.coordinate.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
    
    private func callRestaurant(_ phoneNumber: String) {
        let cleanNumber = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        if let url = URL(string: "tel:\(cleanNumber)") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWebsite(_ website: String) {
        if let url = URL(string: website) {
            UIApplication.shared.open(url)
        }
    }
    
    private func loadExistingRating() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        isLoadingRating = true
        
        // Load existing rating from history entries for this restaurant
        FirebaseService.shared.getHistoryEntries(userId: userId) { entries, error in
            DispatchQueue.main.async {
                self.isLoadingRating = false
                
                if error == nil {
                    // Find the most recent history entry for this restaurant that has a rating
                    let restaurantEntries = entries.filter { 
                        $0.resultType == "restaurant" && $0.resultId == self.restaurant.id 
                    }
                    
                    // Get the most recent rating given to this restaurant
                    let sortedEntries = restaurantEntries.sorted { $0.timestamp > $1.timestamp }
                    if let mostRecentRating = sortedEntries.first(where: { $0.rating != nil })?.rating {
                        self.userRating = mostRecentRating
                        print("✅ Loaded existing rating for restaurant \(self.restaurant.name): \(self.userRating) stars")
                    }
                } else if let error = error {
                    print("❌ Failed to load existing rating: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveRestaurantRating(_ rating: Double) {
        guard let userId = AuthService.shared.currentUser?.id else { 
            print("❌ No user logged in")
            return 
        }
        
        // Update local state immediately
        userRating = rating
        isLoadingRating = true
        
        // Find and update all history entries for this restaurant
        FirebaseService.shared.getHistoryEntries(userId: userId) { entries, error in
            DispatchQueue.main.async {
                if error == nil {
                    let restaurantEntries = entries.filter { 
                        $0.resultType == "restaurant" && $0.resultId == self.restaurant.id 
                    }
                    
                    let group = DispatchGroup()
                    var updateSuccessful = true
                    
                    // Update all history entries for this restaurant
                    for entry in restaurantEntries {
                        group.enter()
                        FirebaseService.shared.updateHistoryEntryRating(
                            id: entry.id, 
                            userId: userId, 
                            rating: rating
                        ) { error in
                            if error != nil {
                                updateSuccessful = false
                                print("❌ Failed to update history entry rating: \(error?.localizedDescription ?? "Unknown error")")
                            }
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: .main) {
                        self.isLoadingRating = false
                        if updateSuccessful {
                            print("✅ Restaurant rating saved successfully to all history entries")
                            // Save rating to global ratings collection
                            self.saveGlobalRating(for: self.restaurant.id, rating: rating, type: "restaurant")
                            // Notify other views to refresh
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshHistory"), object: nil)
                        }
                    }
                    
                } else if let error = error {
                    self.isLoadingRating = false
                    print("❌ Failed to get history entries for rating update: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadAverageRating() {
        isLoadingAverageRating = true
        
        FirebaseService.shared.getAverageRating(itemId: restaurant.id, itemType: "restaurant") { average, count, error in
            DispatchQueue.main.async {
                self.isLoadingAverageRating = false
                if error == nil {
                    self.averageRating = average
                    self.ratingCount = count
                    print("✅ Loaded average rating for restaurant: \(average) (\(count) ratings)")
                } else if let error = error {
                    print("❌ Failed to load average rating: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveGlobalRating(for itemId: String, rating: Double, type: String) {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        FirebaseService.shared.saveGlobalRating(itemId: itemId, itemType: type, userId: userId, rating: rating, comment: "") { error in
            if error == nil {
                print("✅ Global rating saved successfully")
                // Reload average rating to show updated stats
                DispatchQueue.main.async {
                    self.loadAverageRating()
                }
            } else if let error = error {
                print("❌ Failed to save global rating: \(error.localizedDescription)")
            }
        }
    }
}

struct ContactRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DirectionsView: View {
    let restaurant: Restaurant
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(NSLocalizedString("route_guidance", comment: "Route guidance"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    Button(action: {
                        openInAppleMaps()
                    }) {
                        HStack {
                            Image(systemName: "map")
                            Text(NSLocalizedString("open_in_apple_maps", comment: "Open in Apple Maps"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        openInGoogleMaps()
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text(NSLocalizedString("open_in_google_maps", comment: "Open in Google Maps"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        copyAddress()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text(NSLocalizedString("copy_address", comment: "Copy address"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func openInAppleMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: restaurant.coordinate.latitude, longitude: restaurant.coordinate.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        dismiss()
    }
    
    private func openInGoogleMaps() {
        let lat = restaurant.coordinate.latitude
        let lng = restaurant.coordinate.longitude
        let restaurantAddress = restaurant.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Try Google Maps app first with address search
        if let googleMapsURL = URL(string: "comgooglemaps://?q=\(restaurantAddress)&center=\(lat),\(lng)&zoom=15"),
           UIApplication.shared.canOpenURL(googleMapsURL) {
            UIApplication.shared.open(googleMapsURL)
        } else if let googleMapsWebURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(restaurantAddress)&center=\(lat),\(lng)") {
            // Fallback to Google Maps web with address
            UIApplication.shared.open(googleMapsWebURL)
        }
        dismiss()
    }
    
    private func copyAddress() {
        UIPasteboard.general.string = restaurant.address
        dismiss()
    }
}

struct RestaurantShareSheet: View {
    let restaurant: Restaurant
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(NSLocalizedString("share_restaurant", comment: "Share restaurant"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    Button(action: {
                        shareToSocialMedia()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(NSLocalizedString("share_on_sns", comment: "Share on SNS"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        copyRestaurantInfo()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text(NSLocalizedString("copy_restaurant_info", comment: "Copy restaurant info"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareToSocialMedia() {
        let shareText = "メシセレで見つけたお店: \(restaurant.name)\n住所: \(restaurant.address)"
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
        
        dismiss()
    }
    
    private func copyRestaurantInfo() {
        let restaurantInfo = """
        \(restaurant.name)
        住所: \(restaurant.address)
        電話: \(restaurant.phoneNumber ?? "不明")
        評価: \(String(format: "%.1f", restaurant.rating ?? 0.0)) ★
        """
        UIPasteboard.general.string = restaurantInfo
        dismiss()
    }
}

struct RestaurantDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RestaurantDetailView(restaurant: Restaurant.sampleRestaurants.first!)
        }
    }
} 