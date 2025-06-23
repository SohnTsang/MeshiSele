import Foundation
import Combine

class HistoryViewModel: ObservableObject {
    @Published var historyEntries: [HistoryEntry] = []
    @Published var recentEntries: [HistoryEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // Filter options
    @Published var selectedFilterType: HistoryFilterType = .all
    @Published var selectedSortOrder: HistorySortOrder = .newest
    
    // Add missing properties
    @Published var selectedEntry: HistoryEntry? = nil
    @Published var showingDetail: Bool = false
    @Published var filterMealMode: String? = nil
    
    // Add additional filter properties needed by HistoryView
    @Published var filterDietType: String? = nil
    @Published var filterRating: Int? = nil
    @Published var filterStartDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var filterEndDate: Date = Date()
    @Published var sortOption: HistorySortOrder = .newest
    
    private var cancellables: Set<AnyCancellable> = []
    
    // Thread safety
    private let stateQueue = DispatchQueue(label: "com.meshisele.historyviewmodel.state", qos: .userInitiated)
    
    // Add computed properties
    var filteredAndSortedEntries: [HistoryEntry] {
        return filterAndSortEntries(historyEntries, filterType: selectedFilterType, sortOrder: selectedSortOrder)
    }
    
    var hasActiveFilters: Bool {
        return (selectedFilterType != .all && selectedFilterType != .decided) || filterMealMode != nil || filterDietType != nil || filterRating != nil
    }
    
    enum HistoryFilterType: String, CaseIterable {
        case all = "all"
        case decided = "decided"
        case recipes = "recipes"
        case restaurants = "restaurants"
        case rated = "rated"
        case unrated = "unrated"
        
        var displayName: String {
            switch self {
            case .all:
                return "すべて"
            case .decided:
                return "決定済み"
            case .recipes:
                return "レシピ"
            case .restaurants:
                return "レストラン"
            case .rated:
                return "評価済み"
            case .unrated:
                return "未評価"
            }
        }
    }
    
    enum HistorySortOrder: String, CaseIterable {
        case newest = "newest"
        case oldest = "oldest"
        case rating = "rating"
        case dateDescending = "dateDescending"
        case dateAscending = "dateAscending"
        
        var displayName: String {
            switch self {
            case .newest, .dateDescending:
                return "新しい順"
            case .oldest, .dateAscending:
                return "古い順"
            case .rating:
                return "評価順"
            }
        }
    }
    
    init() {
        setupPublishers()
        loadHistory()
    }
    
    deinit {
        // Cancel all subscriptions to prevent retain cycles
        cancellables.removeAll()
    }
    
    private func setupPublishers() {
        // Update filtered entries when filter or sort changes
        Publishers.CombineLatest3($historyEntries, $selectedFilterType, $selectedSortOrder)
            .map { [weak self] entries, filterType, sortOrder in
                return self?.filterAndSortEntries(entries, filterType: filterType, sortOrder: sortOrder) ?? []
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Trigger UI update
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadHistory() {
        guard let userId = AuthService.shared.currentUser?.id else {
            return
        }
        
        setIsLoading(true)
        setErrorMessage(nil)
        
        FirebaseService.shared.getHistoryEntries(userId: userId) { [weak self] entries, error in
            DispatchQueue.main.async { [weak self] in
                self?.setIsLoading(false)
                
                if let error = error {
                    self?.setErrorMessage(error.localizedDescription)
                    return
                }
                
                self?.setHistoryEntries(entries)
                self?.setRecentEntries(Array(entries.prefix(5))) // Show 5 most recent
            }
        }
    }
    
    func refreshHistory() {
        loadHistory()
    }
    
    // MARK: - Filtering and Sorting
    
    private func filterAndSortEntries(_ entries: [HistoryEntry], filterType: HistoryFilterType, sortOrder: HistorySortOrder) -> [HistoryEntry] {
        // First filter out any non-decision entries (spinner results)
        var filtered = entries.filter { $0.resultType == "recipe" || $0.resultType == "restaurant" }
        
        // Apply additional filters
        switch filterType {
        case .all:
            break
        case .decided:
            filtered = filtered.filter { $0.isDecided }
        case .recipes:
            filtered = filtered.filter { $0.resultType == "recipe" }
        case .restaurants:
            filtered = filtered.filter { $0.resultType == "restaurant" }
        case .rated:
            filtered = filtered.filter { $0.rating != nil }
        case .unrated:
            filtered = filtered.filter { $0.rating == nil }
        }
        
        // Apply sort
        switch sortOrder {
        case .newest, .dateDescending:
            filtered = filtered.sorted { $0.timestamp > $1.timestamp }
        case .oldest, .dateAscending:
            filtered = filtered.sorted { $0.timestamp < $1.timestamp }
        case .rating:
            filtered = filtered.sorted { entry1, entry2 in
                let rating1 = entry1.rating ?? 0
                let rating2 = entry2.rating ?? 0
                if rating1 == rating2 {
                    return entry1.timestamp > entry2.timestamp
                }
                return rating1 > rating2
            }
        }
        
        return filtered
    }
    
    // MARK: - History Management
    
    func deleteEntry(_ entry: HistoryEntry) {
        guard let userId = AuthService.shared.currentUser?.id else {
            return
        }
        
        FirebaseService.shared.deleteHistoryEntry(id: entry.id, userId: userId) { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                if let error = error {
                    self?.setErrorMessage(error.localizedDescription)
                } else {
                    // Update arrays safely on main thread
                    self?.historyEntries.removeAll { $0.id == entry.id }
                    self?.recentEntries.removeAll { $0.id == entry.id }
                }
            }
        }
    }
    
    func updateRating(for entry: HistoryEntry, rating: Double) {
        guard let userId = AuthService.shared.currentUser?.id else {
            return
        }
        
        FirebaseService.shared.updateHistoryEntryRating(id: entry.id, userId: userId, rating: rating) { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                if let error = error {
                    self?.setErrorMessage(error.localizedDescription)
                } else {
                    // Update local data safely on main thread
                    if let index = self?.historyEntries.firstIndex(where: { $0.id == entry.id }) {
                        self?.historyEntries[index].rating = rating
                    }
                    if let index = self?.recentEntries.firstIndex(where: { $0.id == entry.id }) {
                        self?.recentEntries[index].rating = rating
                    }
                }
            }
        }
    }
    
    func updateHistoryEntry(_ updatedEntry: HistoryEntry) {
        guard let userId = AuthService.shared.currentUser?.id else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            // Update local data
            if let index = self?.historyEntries.firstIndex(where: { $0.id == updatedEntry.id }) {
                self?.historyEntries[index] = updatedEntry
            }
            if let index = self?.recentEntries.firstIndex(where: { $0.id == updatedEntry.id }) {
                self?.recentEntries[index] = updatedEntry
            }
        }
        
        // Update in Firebase
        FirebaseService.shared.updateHistoryEntry(updatedEntry, userId: userId) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.setErrorMessage(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Re-execution
    
    func redoEntry(_ entry: HistoryEntry, homeViewModel: HomeViewModel) {
        // Restore the filters from the history entry
        if let mealMode = MealMode(rawValue: entry.mealMode) {
            homeViewModel.selectedMealMode = mealMode
        }
        
        if let dietFilter = DietFilter(rawValue: entry.dietFilter) {
            homeViewModel.selectedDietFilter = dietFilter
        }
        
        if let cuisine = entry.cuisine {
            homeViewModel.selectedCuisine = CuisineOption(rawValue: cuisine)
        }
        
        homeViewModel.isSurprise = entry.isSurprise
        homeViewModel.specifiedIngredients = entry.specifiedIngredients
        homeViewModel.excludedIngredients = entry.excludedIngredients
        homeViewModel.servingsCount = entry.servingsCount
        
        if let budget = BudgetOption(rawValue: entry.budgetRange) {
            homeViewModel.budgetRange = budget
        }
        
        if let cookTime = CookTimeOption(rawValue: entry.cookTimeConstraint) {
            homeViewModel.cookTimeConstraint = cookTime
        }
        
        // Clear any existing results
        homeViewModel.clearResult()
        
        // Execute the decision with the restored parameters
        homeViewModel.decideMeal()
    }
    
    // MARK: - Statistics
    
    var totalDecisions: Int {
        return historyEntries.count
    }
    
    var recipeDecisions: Int {
        return historyEntries.filter { $0.resultType == "recipe" }.count
    }
    
    var restaurantDecisions: Int {
        return historyEntries.filter { $0.resultType == "restaurant" }.count
    }
    
    var averageRating: Double {
        let ratedEntries = historyEntries.compactMap { $0.rating }
        guard !ratedEntries.isEmpty else { return 0 }
        
        let sum = ratedEntries.reduce(0, +)
        return Double(sum) / Double(ratedEntries.count)
    }
    
    var mostUsedDietFilter: String? {
        let dietFilters = historyEntries.map { $0.dietFilter }
        let counts = Dictionary(grouping: dietFilters, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    var mostUsedCuisine: String? {
        let cuisines = historyEntries.compactMap { $0.cuisine }
        guard !cuisines.isEmpty else { return nil }
        
        let counts = Dictionary(grouping: cuisines, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Search
    
    func searchHistory(query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return historyEntries }
        
        let lowercaseQuery = query.lowercased()
        
        return historyEntries.filter { entry in
            // Search in diet filter
            if entry.dietFilter.lowercased().contains(lowercaseQuery) {
                return true
            }
            
            // Search in cuisine
            if let cuisine = entry.cuisine, cuisine.lowercased().contains(lowercaseQuery) {
                return true
            }
            
            // Search in specified ingredients
            if entry.specifiedIngredients.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
                return true
            }
            
            // Search in meal mode
            if entry.mealMode.lowercased().contains(lowercaseQuery) {
                return true
            }
            
            return false
        }
    }
    
    // MARK: - Export/Share
    
    func exportHistoryAsText() -> String {
        var text = "MealDecider History Export\n"
        text += "==========================\n\n"
        
        for entry in historyEntries {
            text += "Date: \(entry.formattedDate)\n"
            text += "Mode: \(entry.mealModeDisplayName)\n"
            text += "Diet: \(entry.dietFilter)\n"
            
            if let cuisine = entry.cuisine {
                text += "Cuisine: \(cuisine)\n"
            }
            
            if !entry.specifiedIngredients.isEmpty {
                text += "Ingredients: \(entry.specifiedIngredients.joined(separator: ", "))\n"
            }
            
            if !entry.excludedIngredients.isEmpty {
                text += "Excluded: \(entry.excludedIngredients.joined(separator: ", "))\n"
            }
            
            text += "Rating: \(entry.ratingDisplay)\n"
            text += "\n"
        }
        
        return text
    }
    
    // MARK: - Cleanup
    
    func clearAllHistory() {
        guard let userId = AuthService.shared.currentUser?.id else {
            return
        }
        
        // This would require a batch delete operation in a real implementation
        // For now, we'll delete entries one by one
        let group = DispatchGroup()
        var hasError = false
        
        for entry in historyEntries {
            group.enter()
            FirebaseService.shared.deleteHistoryEntry(id: entry.id, userId: userId) { error in
                if error != nil {
                    hasError = true
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            if hasError {
                self?.errorMessage = "一部の履歴を削除できませんでした。"
            } else {
                self?.historyEntries.removeAll()
                self?.recentEntries.removeAll()
            }
        }
    }
    
    // Add missing methods
    func exportHistory() {
        // Implementation for exporting history
        print("Export history functionality")
    }
    
    func refreshHistoryAsync() {
        // Use thread-safe approach instead of Task/MainActor
        DispatchQueue.main.async { [weak self] in
            self?.refreshHistory()
        }
    }
    
    func redoDecision(_ entry: HistoryEntry) {
        // Implementation for redoing a decision
        selectedEntry = entry
        print("Redo decision for entry: \(entry.id)")
    }
    
    func clearError() {
        setErrorMessage(nil)
    }
    
    func clearFilters() {
        selectedFilterType = .all
        filterMealMode = nil
        filterDietType = nil
        filterRating = nil
    }
    
    // Thread-safe property setters
    private func setHistoryEntries(_ entries: [HistoryEntry]) {
        DispatchQueue.main.async { [weak self] in
            self?.historyEntries = entries
        }
    }
    
    private func setRecentEntries(_ entries: [HistoryEntry]) {
        DispatchQueue.main.async { [weak self] in
            self?.recentEntries = entries
        }
    }
    
    private func setIsLoading(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = value
        }
    }
    
    private func setErrorMessage(_ message: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
        }
    }
} 