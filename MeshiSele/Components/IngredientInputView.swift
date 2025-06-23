import SwiftUI

struct IngredientInputView: View {
    @Binding var selectedIngredients: [String]
    @State private var inputText: String = ""
    @State private var showSuggestions: Bool = false
    @State private var suggestions: [String] = []
    @State private var searchWorkItem: DispatchWorkItem?
    @StateObject private var ingredientService = IngredientService.shared
    
    private let themeOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    private let searchDebounceTime: TimeInterval = 0.3
    
    private var arrangedIngredients: [[String]] {
        var result: [[String]] = []
        var currentRow: [String] = []
        var currentRowWidth: CGFloat = 0
        let maxWidth: CGFloat = UIScreen.main.bounds.width - 32 // Account for padding
        let spacing: CGFloat = 8
        
        for ingredient in selectedIngredients {
            // Estimate tag width (text width + padding + icon)
            let estimatedWidth = ingredient.count * 8 + 40 // Rough estimate
            
            if currentRowWidth + CGFloat(estimatedWidth) + spacing > maxWidth && !currentRow.isEmpty {
                result.append(currentRow)
                currentRow = [ingredient]
                currentRowWidth = CGFloat(estimatedWidth)
            } else {
                currentRow.append(ingredient)
                currentRowWidth += CGFloat(estimatedWidth) + spacing
            }
        }
        
        if !currentRow.isEmpty {
            result.append(currentRow)
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Input field with suggestions
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    TextField("食材を入力してください", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: inputText) { newValue in
                            performDebouncedSearch(query: newValue)
                        }
                        .onSubmit {
                            addIngredient()
                        }
                    
                    Button("追加") {
                        addIngredient()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(canAddIngredient ? themeOrange : Color.gray.opacity(0.3))
                    )
                    .foregroundColor(.white)
                    .disabled(!canAddIngredient)
                }
                
                // Dropdown suggestions
                if showSuggestions && !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                selectSuggestion(suggestion)
                            }) {
                                HStack {
                                    Text(suggestion)
                                        .foregroundColor(.primary)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if suggestion != suggestions.last {
                                Divider()
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .zIndex(1)
                }
            }
            
            // Selected ingredients tags
            if !selectedIngredients.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(arrangedIngredients, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.self) { ingredient in
                                IngredientTag(
                                    text: ingredient,
                                    onRemove: {
                                        removeIngredient(ingredient)
                                    }
                                )
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .onTapGesture {
            // Dismiss suggestions when tapping outside
            hideSuggestions()
        }
    }
    
    // MARK: - Search Optimization Functions
    
    private func performDebouncedSearch(query: String) {
        // Cancel previous search
        searchWorkItem?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Hide suggestions immediately if query is empty
        if trimmed.isEmpty {
            hideSuggestions()
            return
        }
        
        // Create new debounced search work item
        let workItem = DispatchWorkItem { [weak ingredientService] in
            guard let ingredientService = ingredientService else { return }
            
            let results = ingredientService.searchIngredients(query: trimmed)
            
            DispatchQueue.main.async {
                self.suggestions = results
                self.showSuggestions = !results.isEmpty
            }
        }
        
        searchWorkItem = workItem
        
        // Execute after debounce time
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + searchDebounceTime, execute: workItem)
    }
    
    private func hideSuggestions() {
        showSuggestions = false
        suggestions = []
        searchWorkItem?.cancel()
    }
    
    private var canAddIngredient: Bool {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && 
               ingredientService.isValidIngredient(trimmed) && 
               !selectedIngredients.contains(trimmed)
    }
    
    private func addIngredient() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard canAddIngredient else {
            // Show feedback for invalid ingredient
            if !trimmed.isEmpty && !ingredientService.isValidIngredient(trimmed) {
                // Could add haptic feedback or error message here
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            return
        }
        
        selectedIngredients.append(trimmed)
        inputText = ""
        hideSuggestions()
        
        // Success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func selectSuggestion(_ suggestion: String) {
        guard !selectedIngredients.contains(suggestion) else { return }
        
        selectedIngredients.append(suggestion)
        inputText = ""
        hideSuggestions()
        
        // Success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func removeIngredient(_ ingredient: String) {
        selectedIngredients.removeAll { $0 == ingredient }
        
        // Removal feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

struct IngredientTag: View {
    let text: String
    let onRemove: () -> Void
    
    private let themeOrange = Color(red: 1.0, green: 0.6, blue: 0.0)
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(themeOrange.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(themeOrange.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundColor(themeOrange)
    }
}



// Preview
struct IngredientInputView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            IngredientInputView(selectedIngredients: .constant(["鶏肉", "玉ねぎ", "トマト"]))
                .padding()
            
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
} 