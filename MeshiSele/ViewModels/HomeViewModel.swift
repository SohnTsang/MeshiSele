import Foundation
import Combine
import UserNotifications
import SwiftUI
import Network

class HomeViewModel: ObservableObject {
    // Required Selections
    @Published var selectedMealMode: MealMode? = nil
    @Published var selectedDietFilter: DietFilter? = .all
    
    // Optional Selections
    @Published var selectedCuisine: CuisineOption? = nil
    @Published var isSurprise: Bool? = nil
    @Published var specifiedIngredients: [String] = []
    @Published var excludedIngredients: [String] = []
    @Published var excludedAllergens: [String] = []
    @Published var servingsCount: Int = 1
    @Published var budgetRange: BudgetOption = .noLimit
    @Published var cookTimeConstraint: CookTimeOption = .noLimit

    
    // UI State
    @Published var isReadyToDecide: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var spinnerResult: MealResult? = nil
    @Published var latestResult: MealResult? = nil
    private var isClearing = false
    private var pendingResult: MealResult? = nil // Store result until spinner completes

    @Published var validationErrors: [String] = []
    @Published var showCongratulationsOverlay: Bool = false
    @Published var showFullScreenError: Bool = false
    @Published var showingRestaurantList = false
    @Published var restaurantList: [Restaurant] = []
    @Published var isSearchingRestaurants = false
    
    // Spinner animation
    @Published var isSpinning: Bool = false
    @Published var spinnerRotation: Double = 0
    @Published var showFullScreenSpinner: Bool = false
    
    // Track spinner start time for minimum duration
    private var spinnerStartTime: Date?
    
    // Track if user manually changed surprise mode
    private var hasUserManuallyChangedSurpriseMode: Bool = false
    
    // Track rerun count for ad frequency
    private var rerunCount: Int = 0
    
    @Published var isOffline: Bool = false
    @Published var offlineErrorMessage: String? = nil
    
    private var cancellables: Set<AnyCancellable> = []
    
    // Thread safety
    private let stateQueue = DispatchQueue(label: "com.meshisele.homeviewmodel.state", qos: .userInitiated)
    
    private var networkMonitor = NWPathMonitor()
    
    init() {
        print("🏠🏠🏠 HomeViewModel: Initializing...")
        
        // Initialize with default values
        selectedMealMode = nil
        selectedDietFilter = .all  // Set default diet filter immediately
        selectedCuisine = nil
        isSurprise = nil
        specifiedIngredients = []
        excludedIngredients = []
        excludedAllergens = []
        servingsCount = 1
        budgetRange = .noLimit
        cookTimeConstraint = .noLimit

        
        // Setup reactive behaviors first
        setupLocationTracking()
        setupNetworkMonitoring()
        setupValidation()
        
        // Load user preferences after setup
        loadDefaultPreferences()
        
        print("🏠 HomeViewModel: Initialization complete")
        
        // Load default preferences from user settings
        AuthService.shared.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                if user != nil {
                    self?.loadDefaultPreferences()
                }
            }
            .store(in: &cancellables)
        
        // Listen for default settings updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DefaultSettingsUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadDefaultPreferences()
        }
    }
    
    deinit {
        // CRITICAL: Cancel all subscriptions and async operations safely
        if Thread.isMainThread {
            cancellables.removeAll()
        } else {
            DispatchQueue.main.async {
                self.cancellables.removeAll()
            }
        }
        
        networkMonitor.cancel()
    }
    
    // Thread-safe property setters
    func setIsLoading(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = value
        }
    }
    
    private func setErrorMessage(_ message: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.showFullScreenError = message != nil
        }
    }
    
    private func setSpinnerResult(_ result: MealResult?) {
        DispatchQueue.main.async { [weak self] in
            self?.spinnerResult = result
        }
    }
    
    private func setIsSpinning(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpinning = value
        }
    }
    
    private func setIsReadyToDecide(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isReadyToDecide = value
        }
    }
    
    private func setRestaurantList(_ restaurants: [Restaurant]) {
        DispatchQueue.main.async { [weak self] in
            self?.restaurantList = restaurants
        }
    }
    
    private func setShowingRestaurantList(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.showingRestaurantList = value
        }
    }
    
    private func setupValidation() {
        Publishers.CombineLatest3($selectedMealMode, $selectedDietFilter, $isSurprise)
            .map { mealMode, dietFilter, isSurprise in
                // Only require meal mode selection, diet filter is now optional but will be defaulted
                return mealMode != nil && isSurprise != nil
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.setIsReadyToDecide(value)
            }
            .store(in: &cancellables)
        
        // Set up diet filter defaulting when meal mode is first selected
        $selectedMealMode
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mealMode in
                // Always reload preferences when meal mode changes to ensure correct defaults
                print("🔄 HomeViewModel: Meal mode changed to \(mealMode), reloading preferences")
                self?.loadDefaultPreferences()
            }
            .store(in: &cancellables)
    }
    
    private func loadDefaultPreferences() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If no user is logged in, use app defaults
            guard let user = AuthService.shared.currentUser else {
                // Set app defaults when no user is available
                self.selectedDietFilter = .all
                return
            }
            
            let prefs = user.defaultPreferences
            let currentMode = self.selectedMealMode ?? .cook
            
            print("🔄 HomeViewModel: Loading default preferences for mode: \(currentMode)")
            
            // Preserve custom budget if user has set one (don't override with defaults)
            let currentBudgetIsCustom = {
                switch self.budgetRange {
                case .custom:
                    return true
                default:
                    return false
                }
            }()
            
            // Load preferences based on current meal mode
            if currentMode == .cook {
                // Always set diet filter based on saved preference or default
                if let dietFilter = prefs.cookDietFilter {
                    // Handle legacy "normal" values by converting to "all"
                    let finalDietFilter = dietFilter == "normal" ? "all" : dietFilter
                    self.selectedDietFilter = DietFilter(rawValue: finalDietFilter) ?? .all
                    print("📱 HomeViewModel: Set cook diet filter to saved preference: \(dietFilter) -> \(finalDietFilter)")
                } else {
                    // Default to "all" if no preference is saved
                    self.selectedDietFilter = .all
                    print("📱 HomeViewModel: Set cook diet filter to default: all")
                }
                if let cuisine = prefs.cookCuisine {
                    self.selectedCuisine = CuisineOption(rawValue: cuisine)
                } else {
                    // Default to "all" if no preference is saved
                    self.selectedCuisine = .all
                }
                self.isSurprise = prefs.cookIsSurprise
                self.specifiedIngredients = prefs.cookSpecifiedIngredients
                self.excludedIngredients = prefs.cookExcludedIngredients
                self.excludedAllergens = prefs.cookExcludedAllergens
                self.servingsCount = prefs.cookServingsCount
                
                // Only override budget if user hasn't set a custom budget
                if !currentBudgetIsCustom {
                    self.budgetRange = BudgetOption(rawValue: prefs.cookBudgetRange) ?? .noLimit
                } else {
                    print("📱 HomeViewModel: Preserving user's custom budget setting: \(self.budgetRange)")
                }
                
                self.cookTimeConstraint = CookTimeOption(rawValue: prefs.cookCookTimeConstraint) ?? .noLimit
            } else {
                // Always set diet filter based on saved preference or default
                if let dietFilter = prefs.eatOutDietFilter {
                    // Handle legacy "normal" values by converting to "all"
                    let finalDietFilter = dietFilter == "normal" ? "all" : dietFilter
                    self.selectedDietFilter = DietFilter(rawValue: finalDietFilter) ?? .all
                    print("📱 HomeViewModel: Set eatOut diet filter to saved preference: \(dietFilter) -> \(finalDietFilter)")
                } else {
                    // Default to "all" if no preference is saved
                    self.selectedDietFilter = .all
                    print("📱 HomeViewModel: Set eatOut diet filter to default: all")
                }
                if let cuisine = prefs.eatOutCuisine {
                    self.selectedCuisine = CuisineOption(rawValue: cuisine)
                } else {
                    // Default to "all" if no preference is saved
                    self.selectedCuisine = .all
                }
                self.isSurprise = prefs.eatOutIsSurprise
                self.specifiedIngredients = prefs.eatOutSpecifiedIngredients
                self.excludedIngredients = prefs.eatOutExcludedIngredients
                self.excludedAllergens = prefs.eatOutExcludedAllergens
                
                // Only override budget if user hasn't set a custom budget
                if !currentBudgetIsCustom {
                    self.budgetRange = BudgetOption(rawValue: prefs.eatOutBudgetRange) ?? .noLimit
                } else {
                    print("📱 HomeViewModel: Preserving user's custom budget setting: \(self.budgetRange)")
                }
            }
            
            // Migrate legacy "normal" diet filter values to "all"
            self.migrateLegacyDietFilterValues(prefs: prefs)
            
            // If we loaded any preferences, consider this as user having set their preference
            if (currentMode == .cook && (prefs.cookDietFilter != nil || prefs.cookIsSurprise)) ||
               (currentMode == .eatOut && (prefs.eatOutDietFilter != nil || prefs.eatOutIsSurprise)) {
                self.hasUserManuallyChangedSurpriseMode = true
            }
        }
    }
    
    // MARK: - Legacy Data Migration
    
    private func migrateLegacyDietFilterValues(prefs: User.DefaultPreferences) {
        guard let user = AuthService.shared.currentUser else { return }
        
        var needsUpdate = false
        var updatedPrefs = prefs
        
        // Check and migrate cook diet filter
        if let cookDietFilter = prefs.cookDietFilter, cookDietFilter == "normal" {
            updatedPrefs.cookDietFilter = "all"
            needsUpdate = true
            print("🔄 HomeViewModel: Migrating cook diet filter from 'normal' to 'all'")
        }
        
        // Check and migrate eatOut diet filter
        if let eatOutDietFilter = prefs.eatOutDietFilter, eatOutDietFilter == "normal" {
            updatedPrefs.eatOutDietFilter = "all"
            needsUpdate = true
            print("🔄 HomeViewModel: Migrating eatOut diet filter from 'normal' to 'all'")
        }
        
        // Save updated preferences if migration was needed
        if needsUpdate {
            var updatedUser = user
            updatedUser.defaultPreferences = updatedPrefs
            
            // Update in Firebase
            FirebaseService.shared.updateUser(updatedUser) { error in
                if let error = error {
                    print("❌ HomeViewModel: Failed to migrate legacy diet filter values: \(error)")
                } else {
                    print("✅ HomeViewModel: Successfully migrated legacy diet filter values")
                    // Update the current user in AuthService
                    DispatchQueue.main.async {
                        AuthService.shared.currentUser = updatedUser
                    }
                }
            }
        }
    }
    
    private func setupLocationTracking() {
        // Request location permission when eat out is selected and load preferences when mode changes
        $selectedMealMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mealMode in
                if mealMode == .eatOut {
                    LocationManager.shared.requestLocationPermission()
                }
                
                // When meal mode changes, reload the appropriate default preferences
                // This ensures diet filter is set according to the default for the selected mode
                self?.loadDefaultPreferences()
                
                // Do not auto-select お任せ - let user choose explicitly
                // The isSurprise will remain nil until user makes a selection
            }
            .store(in: &cancellables)
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
                if self?.isOffline == true {
                    self?.offlineErrorMessage = "オフラインモードです。外食の周辺検索は利用できません。"
                } else {
                    self?.offlineErrorMessage = nil
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global())
    }
    
    // MARK: - Ingredient Management
    
    func toggleExcludedIngredient(_ ingredient: String) {
        if excludedIngredients.contains(ingredient) {
            excludedIngredients.removeAll { $0 == ingredient }
        } else {
            excludedIngredients.append(ingredient)
        }
    }
    
    func onSurpriseModeManuallyChanged() {
        hasUserManuallyChangedSurpriseMode = true
    }
    
    // MARK: - Validation
    
    private func validateSelections() -> Bool {
        validationErrors.removeAll()
        
        // Check if offline and trying to eat out
        if isOffline && selectedMealMode == .eatOut {
            validationErrors.append(offlineErrorMessage ?? "オフラインモードでは外食の周辺検索は利用できません。")
            return false
        }
        
        // No other fields are required - ingredients are optional even in specify mode
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Meal Decision Logic
    
    func decideMeal() {
        rerunCount = 0 // Reset rerun count for new decision
        executeMealDecision()
    }
    
    func rerunMeal() {
        rerunCount += 1
        executeMealDecision()
    }
    
    func executeMealDecision() {
        guard validateSelections() else {
            // Stop loading state when validation fails
            setIsLoading(false)
            return
        }
        
        guard let mealMode = selectedMealMode else {
            return
        }
        
        // For random mode, use all diet filter as default if none selected
        let dietFilter = selectedDietFilter ?? .all
        
        setIsLoading(true)
        setErrorMessage(nil)
        startFullScreenSpinner()
        
        if mealMode == .cook {
            decideCookingMeal(dietFilter: dietFilter)
        } else {
            decideEatingOutMeal(dietFilter: dietFilter)
        }
    }
    
    private func decideCookingMeal(dietFilter: DietFilter) {
        RecipeService.shared.fetchRandomRecipe(
            dietFilter: dietFilter.rawValue,
            cuisine: selectedCuisine?.displayName,
            specifiedIngredients: (isSurprise == true) ? nil : specifiedIngredients,
            isRandom: isSurprise == true,
            excludedIngredients: excludedIngredients,
            excludedAllergens: excludedAllergens,
            budget: budgetRange,
            maxTime: cookTimeConstraint
        ) { [weak self] recipe in
            DispatchQueue.main.async { [weak self] in
                self?.handleRecipeResult(recipe)
            }
        }
    }
    
    private func decideEatingOutMeal(dietFilter: DietFilter) {
        // First step: Show eating out meal suggestion
        EatingOutMealService.shared.fetchRandomEatingOutMeal(
            dietFilter: dietFilter.rawValue,
            cuisine: selectedCuisine?.displayName,
            budget: budgetRange,
            excludedIngredients: excludedIngredients,
            excludedAllergens: excludedAllergens
        ) { [weak self] eatingOutMeal in
            DispatchQueue.main.async { [weak self] in
                self?.handleEatingOutMealResult(eatingOutMeal)
            }
        }
    }
    
    private func handleRecipeResult(_ recipe: Recipe?) {
        guard let recipe = recipe else {
            stopFullScreenSpinner()
            setIsLoading(false)
            setErrorMessage(NSLocalizedString("no_recipe_found", comment: "No recipe found"))
            return
        }
        
        let result = MealResult(type: .recipe, id: recipe.id, data: recipe)
        pendingResult = result
        latestResult = result
        // Do not save recipes to history when just shown - only save when decided
        
        // CRITICAL: Now call stopFullScreenSpinner to complete the spinner and show the result
        stopFullScreenSpinner()
    }
    
    private func handleEatingOutMealResult(_ eatingOutMeal: EatingOutMeal?) {
        guard let eatingOutMeal = eatingOutMeal else {
            stopFullScreenSpinner()
            setIsLoading(false)
            setErrorMessage(NSLocalizedString("no_meal_found", comment: "No meal found"))
            return
        }
        
        let result = MealResult(type: .eatingOutMeal, id: eatingOutMeal.id, data: eatingOutMeal)
        pendingResult = result
        latestResult = result
        // Do not save eating out meals to history when just shown - only save when decided
        
        // CRITICAL: Now call stopFullScreenSpinner to complete the spinner and show the result
        stopFullScreenSpinner()
    }
    
    private func handleRestaurantResult(_ restaurant: Restaurant?) {
        guard let restaurant = restaurant else {
            stopFullScreenSpinner()
            setIsLoading(false)
            setErrorMessage(NSLocalizedString("no_restaurant_found", comment: "No restaurant found"))
            return
        }
        
        let result = MealResult(type: .restaurant, id: restaurant.id, data: restaurant)
        pendingResult = result
        latestResult = result
        // Do not save restaurants to history when just shown - only save when decided
        
        // CRITICAL: Now call stopFullScreenSpinner to complete the spinner and show the result
        stopFullScreenSpinner()
    }
    
    // MARK: - History Management
    
    private func saveToHistory(result: MealResult, isDecided: Bool = false) {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        let historyEntry = HistoryEntry(
            mealMode: selectedMealMode?.rawValue ?? "cook",
            dietFilter: selectedDietFilter?.rawValue ?? "all",
            cuisine: selectedCuisine?.displayName,
            isSurprise: isSurprise ?? false,
            specifiedIngredients: specifiedIngredients,
            excludedIngredients: excludedIngredients,
            servingsCount: servingsCount,
            budgetRange: budgetRange.rawValue,
            cookTimeConstraint: cookTimeConstraint.rawValue,
            resultType: result.type.rawValue,
            resultId: result.id,
            resultName: result.displayName,
            rating: nil,
            userComment: nil,
            isDecided: isDecided
        )
        
        FirebaseService.shared.saveHistoryEntry(historyEntry, userId: userId) { _ in
            // Handle error silently or log to analytics if needed
        }
    }
    
    // MARK: - Spinner Animation
    
    private func startFullScreenSpinner() {
        showFullScreenSpinner = true
        setIsSpinning(true)
        
        spinnerStartTime = Date()
        
        // Start continuous spinning animation that runs for the full duration
        startContinuousSpinning()
    }
    
    private func startContinuousSpinning() {
        // Reset rotation first
        spinnerRotation = 0
        
        // Start a long-running continuous animation
        withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: false)) {
            spinnerRotation += 360 * 50 // Many rotations to ensure continuous spinning
        }
    }
    
    private func stopFullScreenSpinner() {
        guard let startTime = spinnerStartTime else {
            // If no start time recorded, just stop immediately
            showFullScreenSpinner = false
            setIsSpinning(false)
            setIsLoading(false) // Reset loading state
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minimumDuration: TimeInterval = 2.0
        let remainingTime = max(0, minimumDuration - elapsed)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) { [weak self] in
            guard let self = self else { return }
            self.showFullScreenSpinner = false
            self.setIsSpinning(false)
            self.setIsLoading(false) // Always reset loading state when spinner stops
            
            // Stop the continuous spinning animation and reset rotation
            withAnimation(.easeOut(duration: 0.5)) {
                self.spinnerRotation = 0
            }
            self.spinnerStartTime = nil
            
            // Show pending result if available
            if let pending = self.pendingResult {
                self.setSpinnerResult(pending)
                self.pendingResult = nil
            }
        }
    }
    
    private func startSpinnerAnimation() {
        setIsSpinning(true)
        
        withAnimation(.easeInOut(duration: 1.0)) {
            spinnerRotation += 360 * 3 // Spin 3 full rotations
        }
        
        // Stop after animation completes - use weak self to prevent retain cycles
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.stopSpinnerAnimation()
        }
    }
    
    private func stopSpinnerAnimation() {
        setIsSpinning(false)
    }
    

    
    // MARK: - Preferences Management
    
    func savePreferences() {
        guard var user = AuthService.shared.currentUser else { return }
        
        let currentMode = selectedMealMode ?? .cook
        
        // Update preferences based on current meal mode
        if currentMode == .cook {
            user.defaultPreferences.cookDietFilter = selectedDietFilter?.rawValue
            user.defaultPreferences.cookCuisine = selectedCuisine?.rawValue
            user.defaultPreferences.cookIsSurprise = isSurprise ?? false
            user.defaultPreferences.cookSpecifiedIngredients = specifiedIngredients
            user.defaultPreferences.cookExcludedIngredients = excludedIngredients
            user.defaultPreferences.cookExcludedAllergens = excludedAllergens
            user.defaultPreferences.cookServingsCount = servingsCount
            user.defaultPreferences.cookBudgetRange = budgetRange.rawValue
            user.defaultPreferences.cookCookTimeConstraint = cookTimeConstraint.rawValue
        } else {
            user.defaultPreferences.eatOutDietFilter = selectedDietFilter?.rawValue
            user.defaultPreferences.eatOutCuisine = selectedCuisine?.rawValue
            user.defaultPreferences.eatOutIsSurprise = isSurprise ?? false
            user.defaultPreferences.eatOutSpecifiedIngredients = specifiedIngredients
            user.defaultPreferences.eatOutExcludedIngredients = excludedIngredients
            user.defaultPreferences.eatOutExcludedAllergens = excludedAllergens
            user.defaultPreferences.eatOutBudgetRange = budgetRange.rawValue
        }
        
        FirebaseService.shared.updateUser(user) { _ in
            // Handle error silently or log to analytics if needed
        }
        
        // Update AuthService
        AuthService.shared.currentUser = user
    }
    
    func resetToDefaults() {
        selectedMealMode = nil
        selectedDietFilter = nil
        selectedCuisine = nil
        isSurprise = nil
        specifiedIngredients = []
        excludedIngredients = []
        excludedAllergens = []
        servingsCount = 1
        budgetRange = .noLimit
        cookTimeConstraint = .noLimit
        
        savePreferences()
    }
    
    // MARK: - Utility Methods
    
    var mealRequestParams: [String: Any] {
        return [
            "mealMode": selectedMealMode?.rawValue ?? "",
            "dietFilter": selectedDietFilter?.rawValue ?? "",
            "cuisine": selectedCuisine?.rawValue ?? "",
            "isSurprise": isSurprise ?? false,
            "specifiedIngredients": specifiedIngredients,
            "excludedIngredients": excludedIngredients,
            "servingsCount": servingsCount,
            "budgetRange": budgetRange.rawValue,
            "cookTimeConstraint": cookTimeConstraint.rawValue
        ]
    }
    
    func clearError() {
        setErrorMessage(nil)
        showFullScreenError = false
    }
    
    func clearResult() {
        guard !isClearing else {
            return
        }
        
        isClearing = true
        
        // Clear immediately if no spinner is running
        if !isSpinning && !showFullScreenSpinner {
            spinnerResult = nil
            pendingResult = nil
            isClearing = false
        } else {
            // Delay clearing if spinner is still running
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.spinnerResult = nil
                self.pendingResult = nil
                self.isClearing = false
            }
        }
    }
    
    func saveDecisionToHistory() {
        guard let result = spinnerResult else { 
            return 
        }
        
        saveToHistory(result: result, isDecided: true) // User decided on this meal
        
        // Increment popularity counter
        incrementPopularityCounter(for: result)
        
        showCongratulationsOverlay = true
    }
    
    func saveDecisionToHistory(with result: MealResult) {
        saveToHistory(result: result, isDecided: true) // User decided on this meal
        
        // Increment popularity counter
        incrementPopularityCounter(for: result)
        
        showCongratulationsOverlay = true
    }
    
    func searchRestaurantsForEatingOut(with eatingOutMeal: EatingOutMeal) {
        // First, save the eating out meal as decided since user clicked the search button
        let mealResult = MealResult(type: .eatingOutMeal, id: eatingOutMeal.id, data: eatingOutMeal)
        saveToHistory(result: mealResult, isDecided: true) // User decided on this meal by clicking search
        
        // Start loading states
        setIsLoading(true)
        isSearchingRestaurants = true
        
        // Use meal name as primary search term, with keywords as backup
        let primarySearchTerm = eatingOutMeal.name // e.g., "焼肉"
        let backupSearchTerms = eatingOutMeal.searchKeywords.joined(separator: " ") // e.g., "焼肉 yakiniku bbq"
        
        print("🔍 HomeViewModel: Starting restaurant search for meal: \(eatingOutMeal.name)")
        print("🔍 HomeViewModel: Primary search term: '\(primarySearchTerm)'")
        print("🔍 HomeViewModel: Backup search terms: '\(backupSearchTerms)'")
        print("🔍 HomeViewModel: Cuisine: \(eatingOutMeal.cuisine)")
        
        if isOffline {
            print("🔍 HomeViewModel: Using offline mode")
            // In offline mode, use local restaurant data
            PlaceService.shared.fetchRandomRestaurantOffline(
                dietFilter: selectedDietFilter?.rawValue ?? "all",
                cuisine: eatingOutMeal.cuisine,
                budget: budgetRange,
                excludedIngredients: excludedIngredients
            ) { [weak self] restaurant in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.setIsLoading(false)
                    self.isSearchingRestaurants = false
                    
                    if let restaurant = restaurant {
                        // Validate restaurant data before assignment
                        guard !restaurant.name.isEmpty && 
                              !restaurant.id.isEmpty &&
                              restaurant.coordinate.latitude != 0 &&
                              restaurant.coordinate.longitude != 0 else {
                            print("🔍 HomeViewModel: Invalid offline restaurant data")
                            self.setErrorMessage("この料理を提供するお店が見つかりませんでした。条件を変更して再度お試しください。")
                            return
                        }
                        
                        print("🔍 HomeViewModel: Found offline restaurant: \(restaurant.name)")
                        self.setRestaurantList([restaurant])
                        self.setShowingRestaurantList(true)
                    } else {
                        print("🔍 HomeViewModel: No offline restaurant found")
                        self.setErrorMessage("この料理を提供するお店が見つかりませんでした。条件を変更して再度お試しください。")
                    }
                }
            }
        } else {
            print("🔍 HomeViewModel: Using online mode")
            // Online mode - check if Google Places API is available
            if APIKeys.isGooglePlacesAPIKeyConfigured {
                print("🔍 HomeViewModel: Using Google Places API for enhanced search")
                GooglePlacesService.shared.searchRestaurantsForMeal(
                    mealKeywords: primarySearchTerm,
                    cuisine: eatingOutMeal.cuisine,
                    userLocation: LocationManager.shared.currentLocation,
                    budget: budgetRange,
                    excludedIngredients: excludedIngredients,
                    limit: 20
                ) { [weak self] restaurants in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.setIsLoading(false)
                        self.isSearchingRestaurants = false
                        print("🔍 HomeViewModel: Received \(restaurants.count) restaurants from GooglePlacesService")
                        
                        // Add safety checks before updating UI
                        guard !restaurants.isEmpty else {
                            print("🔍 HomeViewModel: No restaurants found, showing error")
                            self.setErrorMessage("この料理を提供するお店が見つかりませんでした。条件を変更して再度お試しください。")
                            return
                        }
                        
                        // Validate restaurant data before assignment
                        let validRestaurants = restaurants.filter { restaurant in
                            // Basic validation to prevent crashes
                            return !restaurant.name.isEmpty && 
                                   !restaurant.id.isEmpty &&
                                   restaurant.coordinate.latitude != 0 &&
                                   restaurant.coordinate.longitude != 0
                        }
                        
                        guard !validRestaurants.isEmpty else {
                            print("🔍 HomeViewModel: No valid restaurants found after filtering")
                            self.setErrorMessage("この料理を提供するお店が見つかりませんでした。条件を変更して再度お試しください。")
                            return
                        }
                        
                        print("🔍 HomeViewModel: Setting restaurant list with \(validRestaurants.count) valid restaurants")
                        
                        // Use thread-safe assignment
                        self.setRestaurantList(validRestaurants)
                        self.setShowingRestaurantList(true)
                        
                        print("🔍 HomeViewModel: Restaurant list updated successfully with Google Places")
                    }
                }
            } else {
                print("🔍 HomeViewModel: Using MapKit fallback (Google Places API not configured)")
                // Fallback to MapKit when Google Places API is not configured
                PlaceService.shared.fetchRestaurantsForMeal(
                    mealKeywords: primarySearchTerm, // Use meal name directly
                    cuisine: eatingOutMeal.cuisine,
                    budget: budgetRange,
                    excludedIngredients: excludedIngredients,
                    limit: 20
                ) { [weak self] restaurants in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.setIsLoading(false)
                    self.isSearchingRestaurants = false
                    print("🔍 HomeViewModel: Received \(restaurants.count) restaurants from PlaceService")
                    
                    // Add safety checks before updating UI
                    guard !restaurants.isEmpty else {
                        print("🔍 HomeViewModel: No restaurants found, showing error")
                        self.setErrorMessage("この料理を提供するお店が見つかりませんでした。条件を変更して再度お試しください。")
                        return
                    }
                    
                    // Validate restaurant data before assignment
                    let validRestaurants = restaurants.filter { restaurant in
                        // Basic validation to prevent crashes
                        return !restaurant.name.isEmpty && 
                               !restaurant.id.isEmpty &&
                               restaurant.coordinate.latitude != 0 &&
                               restaurant.coordinate.longitude != 0
                    }
                    
                    guard !validRestaurants.isEmpty else {
                        print("🔍 HomeViewModel: No valid restaurants found after filtering")
                        self.setErrorMessage("この料理を提供するお店が見つかりませんでした。条件を変更して再度お試しください。")
                        return
                    }
                    
                    print("🔍 HomeViewModel: Setting restaurant list with \(validRestaurants.count) valid restaurants")
                    
                    // Use thread-safe assignment
                    self.setRestaurantList(validRestaurants)
                    self.setShowingRestaurantList(true)
                    
                        print("🔍 HomeViewModel: Restaurant list updated successfully with MapKit")
                    }
                }
            }
        }
    }
    
    private func incrementPopularityCounter(for result: MealResult) {
        switch result.type {
        case .recipe:
            FirebaseService.shared.incrementRecipePopularity(recipeId: result.id) { newCount, _ in
                // Handle error silently or log to analytics if needed
            }
        case .restaurant:
            // For now, we only track recipe popularity
            break
        case .eatingOutMeal:
            // Could implement eating out meal popularity tracking here
            break
        }
    }
    
    func shouldShowAd() -> Bool {
        // Show ad more frequently: on first run and after every rerun
        let shouldShow = rerunCount == 0 || rerunCount % 1 == 0 // Every run after first
        return shouldShow
    }
} 
