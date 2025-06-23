import SwiftUI

// Theme Colors
private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)

struct ChipView: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? themeOrange : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .onTapGesture {
                onTap()
            }
    }
}

struct RemovableChipView: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemGray5))
        )
        .foregroundColor(.primary)
    }
}

struct ChipGroup: View {
    let items: [String]
    let selectedItems: [String]
    let onSelectionChange: (String) -> Void
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
        ], spacing: 8) {
            ForEach(items, id: \.self) { item in
                ChipView(
                    text: item,
                    isSelected: selectedItems.contains(item),
                    onTap: { onSelectionChange(item) }
                )
            }
        }
    }
}

struct RemovableChipGroup: View {
    let items: [String]
    let onRemove: (String) -> Void
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
        ], spacing: 8) {
            ForEach(items, id: \.self) { item in
                RemovableChipView(
                    text: item,
                    onRemove: { onRemove(item) }
                )
            }
        }
    }
}

// MARK: - Ingredient Selection with Categories
struct IngredientChips: View {
    @Binding var selectedIngredients: [String]
    
    // Ingredient categories with emojis
    private let ingredientCategories: [(name: String, emoji: String, items: [String])] = [
        ("肉類", "🥩", ["牛肉", "鶏肉", "豚肉", "ひき肉", "ベーコン", "ソーセージ"]),
        ("魚介類", "🐟", ["サーモン", "マグロ", "エビ", "イカ", "タコ", "アサリ", "ホタテ"]),
        ("野菜", "🥬", ["キャベツ", "レタス", "トマト", "きゅうり", "人参", "玉ねぎ", "じゃがいも", "ブロッコリー"]),
        ("乳製品", "🥛", ["牛乳", "チーズ", "バター", "ヨーグルト", "生クリーム"]),
        ("穀物", "🌾", ["米", "パン", "パスタ", "うどん", "そば", "小麦粉"]),
        ("ナッツ類", "🥜", ["アーモンド", "くるみ", "ピーナッツ", "カシューナッツ"])
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(ingredientCategories, id: \.name) { category in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(category.emoji)
                            .font(.title3)
                        Text(category.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 70, maximum: 100), spacing: 6)
                    ], spacing: 6) {
                        ForEach(category.items, id: \.self) { ingredient in
                            ingredientButton(for: ingredient)
                        }
                    }
                }
            }
        }
    }
    
    private func ingredientButton(for ingredient: String) -> some View {
        let isSelected = selectedIngredients.contains(ingredient)
        
        return Button(action: {
            // Ensure we're working with the current state
            withAnimation(.easeInOut(duration: 0.2)) {
                if isSelected {
                    selectedIngredients.removeAll { $0 == ingredient }
                } else {
                    selectedIngredients.append(ingredient)
                }
            }
        }) {
            Text(ingredient)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(minWidth: 60, minHeight: 32)
                .background(
                    Capsule()
                        .fill(isSelected ? themeOrange : Color(.systemGray6))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? themeOrange : Color.clear, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Allergen Selection (Separate from Ingredients)
struct AllergenChips: View {
    @Binding var excludedAllergens: [String]
    
    // Japanese allergen categories
    private let mandatoryAllergens = [
        ("えび", "🦐"), ("かに", "🦀"), ("くるみ", "🥜"), ("小麦", "🌾"),
        ("そば", "🍜"), ("卵", "🥚"), ("乳", "🥛"), ("落花生", "🥜")
    ]
    
    private let recommendedAllergens = [
        ("あわび", "🐚"), ("いか", "🦑"), ("いくら", "🍣"), ("オレンジ", "🍊"),
        ("カシューナッツ", "🥜"), ("キウイフルーツ", "🥝"), ("牛肉", "🥩"), ("ごま", "🌰"),
        ("さけ", "🐟"), ("さば", "🐟"), ("大豆", "🫘"), ("鶏肉", "🐔"),
        ("バナナ", "🍌"), ("豚肉", "🐷"), ("まつたけ", "🍄"), ("もも", "🍑"),
        ("やまいも", "🍠"), ("りんご", "🍎"), ("ゼラチン", "🍮"), ("マカダミアナッツ", "🥜")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Only show mandatory allergens (necessary ones)
            HStack {
                Text("⚠️")
                    .font(.title3)
                Text("特定原材料（表示義務）")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(mandatoryAllergens, id: \.0) { allergen in
                    HStack {
                        Text(allergen.1)
                            .font(.caption)
                        Text(allergen.0)
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(excludedAllergens.contains(allergen.0) ? Color.red.opacity(0.2) : Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(excludedAllergens.contains(allergen.0) ? Color.red : Color.clear, lineWidth: 1)
                            )
                    )
                    .foregroundColor(excludedAllergens.contains(allergen.0) ? .red : .primary)
                    .onTapGesture {
                        if excludedAllergens.contains(allergen.0) {
                            excludedAllergens.removeAll { $0 == allergen.0 }
                        } else {
                            excludedAllergens.append(allergen.0)
                        }
                    }
                }
            }
        }
    }
}

// Legacy components for backward compatibility

struct DietChips: View {
    @Binding var selectedDiet: String?
    
    private let dietOptions = [
        "ノーマル", "ヘルシー", "ヴィーガン", "グルテンフリー", "ケト"
    ]
    
    var body: some View {
        ChipGroup(
            items: dietOptions,
            selectedItems: selectedDiet != nil ? [selectedDiet!] : [],
            onSelectionChange: { diet in
                if selectedDiet == diet {
                    selectedDiet = nil
                } else {
                    selectedDiet = diet
                }
            }
        )
    }
}

struct CuisineChips: View {
    @Binding var selectedCuisine: String?
    
    private let cuisineOptions = [
        "すべて", "和食", "洋食", "中華", "イタリアン", "その他"
    ]
    
    var body: some View {
        ChipGroup(
            items: cuisineOptions,
            selectedItems: selectedCuisine != nil ? [selectedCuisine!] : [],
            onSelectionChange: { cuisine in
                if selectedCuisine == cuisine {
                    selectedCuisine = nil
                } else {
                    selectedCuisine = cuisine
                }
            }
        )
    }
}

struct ChipView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ChipView(
                text: "サンプル",
                isSelected: false,
                onTap: {}
            )
            
            ChipView(
                text: "選択済み",
                isSelected: true,
                onTap: {}
            )
            
            RemovableChipView(
                text: "削除可能",
                onRemove: {}
            )
            
            ChipGroup(
                items: ["オプション1", "オプション2", "オプション3"],
                selectedItems: ["オプション2"],
                onSelectionChange: { _ in }
            )
        }
        .padding()
    }
} 