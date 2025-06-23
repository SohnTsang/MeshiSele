import SwiftUI

// Theme Colors
private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)

struct FilterCard: View {
    let title: String
    let icon: String
    let isRequired: Bool
    let content: AnyView
    let isValid: Bool
    
    init<Content: View>(
        title: String,
        icon: String,
        isRequired: Bool = false,
        isValid: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.isRequired = isRequired
        self.isValid = isValid
        self.content = AnyView(content())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(themeOrange)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.headline)
                }
                
                Spacer()
                
                if !isValid {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // Content
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isValid ? Color.clear : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// Predefined filter cards for the home screen
struct MealModeFilterCard: View {
    @Binding var selectedMode: MealMode?
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("select_meal_mode", comment: "Select meal mode"),
            icon: "fork.knife",
            isRequired: true,
            isValid: selectedMode != nil
        ) {
            HStack(spacing: 12) {
                ForEach(MealMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedMode = mode
                    }) {
                        HStack {
                            Image(systemName: mode == .cook ? "house" : "building.2")
                            Text(mode.displayName)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedMode == mode ? Color.blue : Color(.systemGray5))
                        )
                        .foregroundColor(selectedMode == mode ? .white : .primary)
                    }
                }
            }
        }
    }
}

struct DietFilterCard: View {
    @Binding var selectedDiet: DietFilter?
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("select_diet_type", comment: "Select diet type"),
            icon: "leaf"
        ) {
            ChipGroup(
                items: DietFilter.allCases.map { $0.displayName },
                selectedItems: selectedDiet != nil ? [selectedDiet!.displayName] : [],
                onSelectionChange: { dietName in
                    if let diet = DietFilter.allCases.first(where: { $0.displayName == dietName }) {
                        selectedDiet = selectedDiet == diet ? nil : diet
                    }
                }
            )
        }
    }
}

struct CuisineFilterCard: View {
    @Binding var selectedCuisine: CuisineOption?
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("select_cuisine", comment: "Select cuisine"),
            icon: "globe.asia.australia"
        ) {
            ChipGroup(
                items: CuisineOption.allCases.map { $0.displayName },
                selectedItems: selectedCuisine != nil ? [selectedCuisine!.displayName] : [],
                onSelectionChange: { cuisineName in
                    if let cuisine = CuisineOption.allCases.first(where: { $0.displayName == cuisineName }) {
                        selectedCuisine = selectedCuisine == cuisine ? nil : cuisine
                    }
                }
            )
        }
    }
}

struct IngredientModeFilterCard: View {
    @Binding var isSurprise: Bool
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("random_or_specify", comment: "Random or specify"),
            icon: "shuffle"
        ) {
            HStack(spacing: 12) {
                Button(action: {
                    isSurprise = true
                }) {
                    HStack {
                        Image(systemName: "shuffle")
                        Text(NSLocalizedString("random", comment: "Random"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isSurprise ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundColor(isSurprise ? .white : .primary)
                }
                
                Button(action: {
                    isSurprise = false
                }) {
                    HStack {
                        Image(systemName: "list.bullet")
                        Text(NSLocalizedString("specify_ingredients", comment: "Specify ingredients"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(!isSurprise ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundColor(!isSurprise ? .white : .primary)
                }
            }
        }
    }
}

struct IngredientsFilterCard: View {
    @Binding var ingredients: [String]
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("enter_ingredients", comment: "Enter ingredients"),
            icon: "carrot"
        ) {
            IngredientInputView(selectedIngredients: $ingredients)
        }
    }
}

struct ExcludedIngredientsFilterCard: View {
    @Binding var excludedIngredients: [String]
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("exclude_ingredients", comment: "Exclude ingredients"),
            icon: "xmark.circle"
        ) {
            IngredientChips(selectedIngredients: $excludedIngredients)
        }
    }
}

struct ServingsFilterCard: View {
    @Binding var servingsCount: Int
    
    private let servingOptions = [
        (1, NSLocalizedString("one_serving", comment: "1 serving")),
        (2, NSLocalizedString("two_servings", comment: "2 servings")),
        (4, NSLocalizedString("three_four_servings", comment: "3-4 servings")),
        (6, NSLocalizedString("five_plus_servings", comment: "5+ servings"))
    ]
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("servings", comment: "Servings"),
            icon: "person.2"
        ) {
            ChipGroup(
                items: servingOptions.map { $0.1 },
                selectedItems: [servingOptions.first(where: { $0.0 == servingsCount })?.1 ?? ""],
                onSelectionChange: { servingName in
                    if let serving = servingOptions.first(where: { $0.1 == servingName }) {
                        servingsCount = serving.0
                    }
                }
            )
        }
    }
}

struct BudgetFilterCard: View {
    @Binding var budgetRange: BudgetOption
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("budget", comment: "Budget"),
            icon: "yensign.circle"
        ) {
            ChipGroup(
                items: BudgetOption.presetCases.map { $0.displayName },
                selectedItems: [budgetRange.displayName],
                onSelectionChange: { budgetName in
                    if let budget = BudgetOption.presetCases.first(where: { $0.displayName == budgetName }) {
                        budgetRange = budget
                    }
                }
            )
        }
    }
}

struct CookingTimeFilterCard: View {
    @Binding var cookTimeConstraint: CookTimeOption
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("cooking_time", comment: "Cooking time"),
            icon: "clock"
        ) {
            ChipGroup(
                items: CookTimeOption.allCases.map { $0.displayName },
                selectedItems: [cookTimeConstraint.displayName],
                onSelectionChange: { timeName in
                    if let time = CookTimeOption.allCases.first(where: { $0.displayName == timeName }) {
                        cookTimeConstraint = time
                    }
                }
            )
        }
    }
}

struct NotificationFilterCard: View {
    @Binding var notificationsEnabled: Bool
    
    var body: some View {
        FilterCard(
            title: NSLocalizedString("receive_reminders", comment: "Receive reminders"),
            icon: "bell"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $notificationsEnabled) {
                    Text(NSLocalizedString("receive_notifications", comment: "Receive notifications"))
                }
                
                Text(NSLocalizedString("notification_settings_note", comment: "Notification settings note"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
} 