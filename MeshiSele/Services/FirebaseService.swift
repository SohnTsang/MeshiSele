import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Network

// Global Rating Model for Firebase Service
struct GlobalRating: Identifiable {
    let id: String
    let userId: String
    let rating: Double
    let comment: String
    let timestamp: Date
    
    init(data: [String: Any], id: String) {
        self.id = id
        self.userId = data["userId"] as? String ?? ""
        self.rating = data["rating"] as? Double ?? 0.0
        self.comment = data["comment"] as? String ?? ""
        
        if let timestamp = data["timestamp"] as? Timestamp {
            self.timestamp = timestamp.dateValue()
        } else {
            self.timestamp = Date()
        }
    }
}

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db: Firestore
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // CRITICAL: Use only main queue to prevent threading issues
    private let dbQueue = DispatchQueue.main
    
    @Published var isConnected = true
    
    private init() {
        // CRITICAL: Ensure Firebase is configured before accessing Firestore
        guard FirebaseApp.app() != nil else {
            print("🔥❌ FATAL: Firebase not configured before FirebaseService initialization")
            fatalError("Firebase must be configured before initializing FirebaseService")
        }
        
        self.db = Firestore.firestore()
        setupNetworkMonitoring()
        configurePersistence()
        
        print("🔥 FirebaseService: Initialized successfully")
    }
    
    deinit {
        print("🔥 FirebaseService: Deinitializing...")
        monitor.cancel()
        print("🔥 FirebaseService: Deinitialized safely")
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                if path.status == .satisfied {
                    print("🌐 Firebase: Network connection available")
                } else {
                    print("❌ Firebase: Network connection unavailable")
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func configurePersistence() {
        let settings = FirestoreSettings()
        
        // Use the new cache settings instead of deprecated properties
        settings.cacheSettings = MemoryCacheSettings()
        
        Firestore.firestore().settings = settings
    }
    
    // Helper to safely execute completion on main thread
    private func safeMainCompletion<T>(_ completion: @escaping (T) -> Void, with value: T) {
        DispatchQueue.main.async {
            completion(value)
        }
    }
    
    private func safeMainCompletion<T, U>(_ completion: @escaping (T, U?) -> Void, with value: T, error: U?) {
        DispatchQueue.main.async {
            completion(value, error)
        }
    }
    
    // MARK: - User Management
    
    func createUser(_ user: User, completion: @escaping (Error?) -> Void) {
        // CRITICAL: All operations on main queue to prevent crashes
        dbQueue.async { [weak self] in
            guard let self = self else {
                completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                return
            }
            
            self.db.collection("users").document(user.id).setData(user.dictionary) { error in
                // Always execute completion on main queue
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    func getUser(id: String, completion: @escaping (User?, Error?) -> Void) {
        // Create a safe completion wrapper that won't crash
        let safeCompletion: (User?, Error?) -> Void = { user, error in
            DispatchQueue.main.async {
                completion(user, error)
            }
        }
        
        dbQueue.async { [weak self] in
            guard let self = self else {
                safeCompletion(nil, NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                return
            }
            
            self.db.collection("users").document(id).getDocument { snapshot, error in
                // Don't use DispatchQueue.main.async here since safeCompletion already does it
                if let error = error {
                    safeCompletion(nil, error)
                    return
                }
                
                if let data = snapshot?.data() {
                    let user = User(data: data, id: id)
                    safeCompletion(user, nil)
                } else {
                    safeCompletion(nil, nil)
                }
            }
        }
    }
    
    func updateUser(_ user: User, completion: @escaping (Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("users").document(user.id).updateData(user.dictionary) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    // MARK: - History Management
    
    func saveHistoryEntry(_ entry: HistoryEntry, userId: String, completion: @escaping (Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("users").document(userId).collection("history").document(entry.id).setData(entry.dictionary) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    func addHistoryEntry(_ entry: HistoryEntry, userId: String, completion: @escaping (Error?) -> Void) {
        saveHistoryEntry(entry, userId: userId, completion: completion)
    }
    
    func getHistoryEntries(userId: String, completion: @escaping ([HistoryEntry], Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion([], NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("users").document(userId).collection("history")
                .order(by: "timestamp", descending: true)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion([], error)
                            return
                        }
                        
                        let entries = snapshot?.documents.compactMap { doc in
                            HistoryEntry(data: doc.data(), id: doc.documentID)
                        } ?? []
                        
                        completion(entries, nil)
                    }
                }
        }
    }
    
    func deleteHistoryEntry(id: String, userId: String, completion: @escaping (Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("users").document(userId).collection("history").document(id).delete { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    func updateHistoryEntryRating(id: String, userId: String, rating: Double, completion: @escaping (Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("users").document(userId).collection("history").document(id).updateData([
                "rating": rating
            ]) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    func updateHistoryEntry(_ entry: HistoryEntry, userId: String, completion: @escaping (Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("users").document(userId).collection("history").document(entry.id).updateData(entry.dictionary) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    // MARK: - Bookmarks Management
    
    func addBookmark(type: String, itemId: String, userId: String, completion: @escaping (Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            let bookmarkData: [String: Any] = [
                "type": type,
                "itemId": itemId,
                "timestamp": Timestamp(date: Date())
            ]
            
            self.db.collection("users").document(userId).collection("bookmarks").addDocument(data: bookmarkData) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    func removeBookmark(type: String, itemId: String, userId: String, completion: @escaping (Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("users").document(userId).collection("bookmarks")
                .whereField("type", isEqualTo: type)
                .whereField("itemId", isEqualTo: itemId)
                .getDocuments { snapshot, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            completion(error)
                        }
                        return
                    }
                    
                    snapshot?.documents.forEach { doc in
                        doc.reference.delete()
                    }
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
        }
    }
    
    func isBookmarked(type: String, itemId: String, userId: String, completion: @escaping (Bool) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            self.db.collection("users").document(userId).collection("bookmarks")
                .whereField("type", isEqualTo: type)
                .whereField("itemId", isEqualTo: itemId)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        completion(!(snapshot?.documents.isEmpty ?? true))
                    }
                }
        }
    }
    
    func getBookmarks(userId: String, completion: @escaping ([DocumentSnapshot], Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion([], NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("users").document(userId).collection("bookmarks")
                .order(by: "timestamp", descending: true)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion([], error)
                            return
                        }
                        
                        completion(snapshot?.documents ?? [], nil)
                    }
                }
        }
    }
    
    // MARK: - Recipe Popularity Tracking
    
    func incrementRecipePopularity(recipeId: String, completion: @escaping (Int?, Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            let recipeRef = self.db.collection("recipes").document(recipeId)
            
            self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                do {
                    let recipeDocument = try transaction.getDocument(recipeRef)
                    let currentCount = recipeDocument.data()?["popularityCount"] as? Int ?? 0
                    let newCount = currentCount + 1
                    
                    transaction.updateData(["popularityCount": newCount], forDocument: recipeRef)
                    return newCount
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }
            }) { (result, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(nil, error)
                    } else if let newCount = result as? Int {
                        completion(newCount, nil)
                    } else {
                        completion(nil, nil)
                    }
                }
            }
        }
    }
    
    func getRecipePopularity(recipeId: String, completion: @escaping (Int?, Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("recipes").document(recipeId).getDocument { snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(nil, error)
                        return
                    }
                    
                    let count = snapshot?.data()?["popularityCount"] as? Int ?? 0
                    completion(count, nil)
                }
            }
        }
    }
    
    // MARK: - Global Ratings Management
    
    func saveGlobalRating(itemId: String, itemType: String, userId: String, rating: Double, comment: String = "", completion: @escaping (Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            let ratingData: [String: Any] = [
                "itemId": itemId,
                "itemType": itemType,
                "userId": userId,
                "rating": rating,
                "comment": comment,
                "timestamp": Timestamp(date: Date())
            ]
            
            // Use user-item combination as document ID to prevent duplicate ratings from same user
            let documentId = "\(userId)_\(itemId)"
            
            self.db.collection("globalRatings").document(documentId).setData(ratingData, merge: true) { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
    
    func getGlobalRatings(itemId: String, itemType: String, completion: @escaping ([GlobalRating]?, Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(nil, NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("globalRatings")
                .whereField("itemId", isEqualTo: itemId)
                .whereField("itemType", isEqualTo: itemType)
                .order(by: "timestamp", descending: true)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(nil, error)
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            completion([], nil)
                            return
                        }
                        
                        let ratings = documents.compactMap { doc in
                            GlobalRating(data: doc.data(), id: doc.documentID)
                        }
                        
                        completion(ratings, nil)
                    }
                }
        }
    }
    
    func getAverageRating(itemId: String, itemType: String, completion: @escaping (Double, Int, Error?) -> Void) {
        dbQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion(0.0, 0, NSError(domain: "FirebaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Service deallocated"]))
                }
                return
            }
            
            self.db.collection("globalRatings")
                .whereField("itemId", isEqualTo: itemId)
                .whereField("itemType", isEqualTo: itemType)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(0.0, 0, error)
                            return
                        }
                        
                        guard let documents = snapshot?.documents, !documents.isEmpty else {
                            completion(0.0, 0, nil)
                            return
                        }
                        
                        let ratings = documents.compactMap { doc in
                            doc.data()["rating"] as? Double
                        }
                        
                        let average = ratings.isEmpty ? 0.0 : ratings.reduce(0, +) / Double(ratings.count)
                        completion(average, ratings.count, nil)
                    }
                }
        }
    }
} 