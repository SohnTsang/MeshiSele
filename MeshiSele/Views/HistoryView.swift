import SwiftUI
import Firebase

// Theme Colors
private let themeOrange = Color(red: 246/255, green: 178/255, blue: 107/255)
private let themeTeal = Color(red: 108/255, green: 201/255, blue: 183/255)

// String extension for consistent localization
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    func localized(defaultValue: String? = nil) -> String {
        return LocalizationManager.shared.localizedString(for: self, defaultValue: defaultValue)
    }
}

// Diet Type Badge Component
struct DietTypeBadge: View {
    let dietFilter: String
    
    private var dietInfo: (emoji: String, name: String, color: Color) {
        if let diet = DietFilter(rawValue: dietFilter) {
            return (
                emoji: diet.emoji,
                name: diet.displayName,
                color: colorForDiet(diet)
            )
        } else {
            return (
                emoji: "🍽️",
                name: "ノーマル",
                color: .gray
            )
        }
    }
    
    private func colorForDiet(_ diet: DietFilter) -> Color {
        switch diet {
        case .all:
            return .gray
        case .healthy:
            return .green
                    case .vegetarian:
            return themeTeal
        case .lowCarb:
            return .purple
        case .glutenFree:
            return .orange
        case .meat:
            return .red
        }
    }
    
    var body: some View {
        Text(dietInfo.name)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(dietInfo.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(dietInfo.color.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(dietInfo.color.opacity(0.3), lineWidth: 0.5)
                    )
            )
    }
}



// Optimized History Entry Row
struct HistoryEntryRow: View {
    let entry: HistoryEntry
    let onTap: () -> Void
    let onRate: ((HistoryEntry) -> Void)?
    
    // Use static formatter to avoid recreating it for each row
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 H:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon with decision indicator
            ZStack {
                Image(systemName: entry.mealMode == "cook" ? "fork.knife" : "building.2")
                    .font(.title3)
                    .foregroundColor(themeOrange)
                    .frame(width: 30)
                
                // Decision indicator
                if entry.isDecided {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(themeTeal)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(x: 12, y: -8)
                } else {
                    Image(systemName: "eye.circle.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .background(Color.white)
                        .clipShape(Circle())
                        .offset(x: 12, y: -8)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(entry.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Status badge - only show if decided
                    if entry.isDecided {
                        Text("決定")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(themeTeal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(themeTeal.opacity(0.1))
                            )
                    }
                }
                
                // Diet type and metadata row
                HStack(spacing: 8) {
                    // Diet type badge - always show
                    DietTypeBadge(dietFilter: entry.dietFilter)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(Self.dateFormatter.string(from: entry.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                // Rating row with interactive rating for all entry types
                HStack {
                    if let rating = entry.rating, rating > 0 {
                        StarRatingView(rating: rating, maxRating: 5, size: 12, isInteractive: false, onRatingChanged: nil)
                    } else {
                        Text("未評価")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                        Spacer()
                    
                    // Add rate button for all entry types (recipes, restaurants, eatingOutMeals)
                    if onRate != nil {
                        Button(action: {
                            print("🔥 HistoryEntryRow: Rating button tapped for entry: \(entry.displayName)")
                            print("🔥 Entry details - ID: \(entry.id), Type: \(entry.resultType), ResultID: \(entry.resultId)")
                            onRate?(entry)
                        }) {
                            Text("評価")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(themeTeal)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeTeal.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct HistoryView: View {
    @Binding var selectedTab: Int
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showingFilterSheet = false
    @State private var entryToDelete: HistoryEntry?
    @State private var showingDeleteAlert = false
    @State private var showingClearAllAlert = false
    @State private var selectedHistoryTab: HistoryTab = .cuisine
    @State private var ratingSheetEntry: HistoryEntry? {
        didSet {
            print("🔥 HistoryView: ratingSheetEntry changed to: \(ratingSheetEntry?.displayName ?? "nil")")
        }
    }
    
    // Use a separate state for filtered entries to reduce view updates
    @State private var filteredEntries: [HistoryEntry] = []
    
    // Filter entries based on selected tab
    private var filteredEntriesForSelectedTab: [HistoryEntry] {
        let baseEntries = filteredEntries.isEmpty ? viewModel.historyEntries : filteredEntries
        
        switch selectedHistoryTab {
        case .cuisine:
            return baseEntries.filter { entry in
                entry.resultType == "recipe" || entry.resultType == "eatingOutMeal"
            }
        case .restaurant:
            return baseEntries.filter { entry in
                entry.resultType == "restaurant" && entry.isDecided
            }
        }
    }
    
    // Tab view for switching between cuisine and restaurant history
    private var historyTabView: some View {
        HStack(spacing: 0) {
            ForEach(HistoryTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedHistoryTab = tab
                    }
                }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.subheadline)
                            Text(tab.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(selectedHistoryTab == tab ? themeTeal : .gray)
                        
                        Rectangle()
                            .fill(selectedHistoryTab == tab ? themeTeal : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selection
                historyTabView
                
                if filteredEntriesForSelectedTab.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        // Filter and Sort Controls
                        filterSortControlsView
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        themeOrange.opacity(0.05),
                                        themeTeal.opacity(0.02)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        // History List with Ads
                        historyListWithAdsView
                    }
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingFilterSheet = true
                        }) {
                            Label("フィルター", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: {
                            viewModel.exportHistory()
                        }) {
                            Label("エクスポート", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            viewModel.refreshHistory()
                        }) {
                            Label("更新", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showingClearAllAlert = true
                        }) {
                            Label("すべて削除", systemImage: "trash.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            })
            .sheet(isPresented: $showingFilterSheet) {
                HistoryFilterSheet(viewModel: viewModel)
            }
            .sheet(item: $ratingSheetEntry) { entry in
                RatingSheetView(entry: entry) { updatedEntry in
                    print("🔥 HistoryView: Rating sheet onSave callback triggered")
                    viewModel.updateHistoryEntry(updatedEntry)
                    ratingSheetEntry = nil
                }
                .onAppear {
                    print("🔥 HistoryView: Rating sheet presented successfully for: \(entry.displayName)")
                    print("🔥 HistoryView: Entry ID: \(entry.id), Type: \(entry.resultType)")
                }
            }
            .refreshable {
                viewModel.refreshHistoryAsync()
            }
        }
        .onAppear {
            viewModel.loadHistory()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHistory"))) { _ in
            print("🔄 HistoryView: Refreshing history due to rating update")
            viewModel.refreshHistory()
        }
        .onChange(of: viewModel.filteredAndSortedEntries) { newEntries in
            // Update filtered entries on a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                let entries = newEntries
                DispatchQueue.main.async {
                    self.filteredEntries = entries
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("まだ履歴がありません")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("最初の食事を決めてみましょう！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                // Switch to Home tab using SwiftUI binding
                selectedTab = 0
            }) {
                Text("今すぐ決定")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(themeOrange)
                    .cornerRadius(25)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var filterSortControlsView: some View {
        HStack(spacing: 16) {
            // Decided/All filter
            Menu {
                Button(action: {
                    viewModel.selectedFilterType = .all
                }) {
                    HStack {
                        Text("すべて")
                        Spacer()
                        if viewModel.selectedFilterType == .all {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    viewModel.selectedFilterType = .decided
                }) {
                    HStack {
                        Text("決定済み")
                        Spacer()
                        if viewModel.selectedFilterType == .decided {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.selectedFilterType == .decided ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(viewModel.selectedFilterType == .decided ? themeTeal : themeOrange)
                        .font(.subheadline)
                    Text(viewModel.selectedFilterType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                )
            }
            
            // Filter indicator
            if viewModel.hasActiveFilters {
                Button(action: {
                    showingFilterSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(themeOrange)
                            .font(.subheadline)
                        Text("フィルター中")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(themeOrange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeOrange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeOrange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            
            Spacer()
            
            // Sort control
            Menu {
                Button(action: {
                    viewModel.sortOption = .dateDescending
                }) {
                    HStack {
                        Text("新しい順")
                        Spacer()
                        if viewModel.sortOption == .dateDescending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    viewModel.sortOption = .dateAscending
                }) {
                    HStack {
                        Text("古い順")
                        Spacer()
                        if viewModel.sortOption == .dateAscending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Button(action: {
                    viewModel.sortOption = .rating
                }) {
                    HStack {
                        Text("評価順")
                        Spacer()
                        if viewModel.sortOption == .rating {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(themeOrange)
                        .font(.subheadline)
                    Text(viewModel.sortOption.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                )
            }
        }
    }
    
    private var historyListWithAdsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredEntriesForSelectedTab.enumerated()), id: \.element.id) { index, entry in
                    VStack(spacing: 0) {
                        // History Entry Row
                        HistoryEntryRow(
                            entry: entry,
                            onTap: {
                                // Fix timing issue: ensure entry is set before showing
                                DispatchQueue.main.async {
                                viewModel.selectedEntry = entry
                                viewModel.showingDetail = true
                                }
                            },
                            onRate: { entry in
                                print("🔥 HistoryView: onRate callback triggered for: \(entry.displayName)")
                                print("🔥 HistoryView: Setting ratingSheetEntry to present sheet")
                                ratingSheetEntry = entry
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(action: {
                                entryToDelete = entry
                                showingDeleteAlert = true
                            }) {
                                Label("削除", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        
                        // Add banner ad after every 3 items or after the last item if less than 3
                        if shouldShowAdAfter(index: index, totalCount: filteredEntriesForSelectedTab.count) {
                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: 16)
                                
                                HistoryBannerAdView()
                                    .padding(.horizontal, 16)
                                
                                Spacer()
                                    .frame(height: 16)
                            }
                        }
                        
                        // Add separator if not the last item
                        if index < filteredEntriesForSelectedTab.count - 1 {
                            Divider()
                                .padding(.leading, 58) // Align with content
                        }
                    }
                }
                
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    }
                    .padding()
                }
                
                // Bottom spacing to match HomeView's decision button spacing
                Spacer()
                    .frame(height: 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $viewModel.showingDetail, onDismiss: {
            // Clean up state when sheet is dismissed
            viewModel.selectedEntry = nil
        }) {
            if let entry = viewModel.selectedEntry {
                HistoryDetailSheet(entry: entry, viewModel: viewModel)
            } else {
                // Fallback view in case of timing issues
                VStack(spacing: 20) {
                    ProgressView("読み込み中...")
                        .font(.headline)
                    
                    Button("閉じる") {
                        viewModel.showingDetail = false
                        viewModel.selectedEntry = nil
                    }
                    .padding()
                    .background(themeOrange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onAppear {
                    // Auto-dismiss if no entry after a brief moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if viewModel.selectedEntry == nil {
                            viewModel.showingDetail = false
                        }
                    }
                }
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .alert("履歴を削除", isPresented: $showingDeleteAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                if let entry = entryToDelete {
                    // Optimistically remove from UI immediately
                    withAnimation(.easeInOut(duration: 0.3)) {
                        filteredEntries.removeAll { $0.id == entry.id }
                    }
                    // Then delete from backend
                    viewModel.deleteEntry(entry)
                    entryToDelete = nil
                }
            }
        } message: {
            Text("この履歴項目を削除してもよろしいですか？この操作は取り消せません。")
        }
        .alert("すべての履歴を削除", isPresented: $showingClearAllAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("すべて削除", role: .destructive) {
                // Clear the UI immediately
                withAnimation(.easeInOut(duration: 0.5)) {
                    filteredEntries.removeAll()
                }
                // Then clear from backend
                viewModel.clearAllHistory()
            }
        } message: {
            Text("すべての履歴を削除してもよろしいですか？この操作は取り消せません。")
        }
    }
    
    // Helper function to determine when to show ads
    private func shouldShowAdAfter(index: Int, totalCount: Int) -> Bool {
        // Show ad after every 3 items (at indices 2, 5, 8, etc.)
        // OR after the last item if there are less than 3 items total
        if totalCount < 3 {
            return index == totalCount - 1
        } else {
            return (index + 1) % 3 == 0
        }
    }
}


struct HistoryFilterSheet: View {
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("料理モード") {
                    Picker("料理モード", selection: $viewModel.filterMealMode) {
                        Text("すべて").tag(nil as String?)
                        Text("料理する").tag("cook" as String?)
                        Text("外食").tag("eatOut" as String?)
                    }
                }
                
                Section("ダイエットタイプ") {
                    Picker("ダイエットタイプ", selection: $viewModel.filterDietType) {
                        Text("すべて").tag(nil as String?)
                        Text("すべて").tag("all" as String?)
                        Text("ヘルシー").tag("healthy" as String?)
                                                        Text("ベジタリアン").tag("vegetarian" as String?)
                        Text("グルテンフリー").tag("glutenFree" as String?)
                        Text("ケト").tag("keto" as String?)
                    }
                }
                
                Section("評価") {
                    Picker("評価", selection: $viewModel.filterRating) {
                        Text("すべて").tag(nil as Int?)
                        Text("☆☆☆☆☆ 5つ星").tag(5 as Int?)
                        Text("☆☆☆☆ 4つ星以上").tag(4 as Int?)
                        Text("☆☆☆ 3つ星以上").tag(3 as Int?)
                    }
                }
                
                Section("期間") {
                    DatePicker("開始日", selection: $viewModel.filterStartDate, displayedComponents: .date)
                    DatePicker("終了日", selection: $viewModel.filterEndDate, displayedComponents: .date)
                }
            }
            .navigationTitle("フィルター")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("リセット") {
                        viewModel.clearFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct HistoryDetailSheet: View {
    let entry: HistoryEntry
    @ObservedObject var viewModel: HistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var userRating: Int = 0
    @State private var userComment: String = ""
    @State private var showingRecipeDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Playful gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        themeOrange.opacity(0.1),
                        themeTeal.opacity(0.05),
                        Color.pink.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header Card - Full Width
                        VStack(alignment: .leading, spacing: 16) {
                            // Title and Date
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 8) {
                                    Image(systemName: entry.mealMode == "cook" ? "fork.knife" : "building.2")
                                        .font(.subheadline)
                                        .foregroundColor(themeOrange)
                                    
                                    Text(DateFormatter.fullDateTime.string(from: entry.timestamp))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Current Rating Display
                            if let rating = entry.rating, rating > 0 {
                                HStack(spacing: 8) {
                                    Text("評価:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    StarRatingView(rating: rating, maxRating: 5, size: 16, isInteractive: false, onRatingChanged: nil)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        
                        LazyVStack(spacing: 20) {
                            RecipeDetailCardView(entry: entry, showingRecipeDetail: $showingRecipeDetail)
                            FilterDetailsCardView(entry: entry)
                            RatingCardView(entry: entry, userRating: $userRating, userComment: $userComment, viewModel: viewModel, dismiss: dismiss)
                        }
                        .padding(.horizontal)
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("履歴詳細")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button(NSLocalizedString("done", comment: "Done")) {
                    dismiss()
                }
            )
        }
        .onAppear {
            userRating = Int(entry.rating ?? 0)
            userComment = entry.userComment ?? ""
        }
        .onChange(of: entry.rating) { newRating in
            // Update local state when entry rating changes
            userRating = Int(newRating ?? 0)
        }
        .sheet(isPresented: $showingRecipeDetail) {
            if entry.mealMode == "cook" && entry.resultType == "recipe" {
                // Load recipe details by ID and show RecipeDetailView
                RecipeDetailLoadingView(recipeId: entry.resultId, servings: entry.servingsCount)
            }
        }
    }
}

// Recipe Detail Card Component
struct RecipeDetailCardView: View {
    let entry: HistoryEntry
    @Binding var showingRecipeDetail: Bool
    
    var body: some View {
        if entry.mealMode == "cook" && entry.resultType == "recipe" {
            PlayfulFilterCard(
                title: "レシピ詳細",
                icon: "book.fill"
            ) {
                VStack(spacing: 16) {
                    Text("このレシピの詳細情報を確認できます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        showingRecipeDetail = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.closed.fill")
                                .font(.headline)
                            Text("レシピを確認")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [themeTeal, themeOrange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(color: themeTeal.opacity(0.3), radius: 12, x: 0, y: 6)
                    }
                }
            }
        }
    }
}

// Filter Details Card Component
struct FilterDetailsCardView: View {
    let entry: HistoryEntry
    
    var body: some View {
        PlayfulFilterCard(
            title: "決定時の条件",
            icon: "slider.horizontal.3"
        ) {
            VStack(spacing: 12) {
                DetailRow(title: "料理モード", value: entry.mealModeDisplayName)
                DetailRow(title: "ダイエットタイプ", value: entry.dietFilterDisplayName)
                
                if !entry.cuisineDisplayName.isEmpty {
                    DetailRow(title: "料理ジャンル", value: entry.cuisineDisplayName)
                }
                
                if !entry.specifiedIngredients.isEmpty {
                    DetailRow(title: "指定食材", value: entry.specifiedIngredients.joined(separator: ", "))
                }
                
                if !entry.excludedIngredients.isEmpty {
                    DetailRow(title: "除外食材", value: entry.excludedIngredients.joined(separator: ", "))
                }
                
                DetailRow(title: "人数", value: "\(entry.servingsCount)人")
                DetailRow(title: "予算", value: entry.budgetRangeDisplayName)
                
                if entry.mealMode == "cook" {
                    DetailRow(title: "調理時間", value: entry.cookTimeConstraintDisplayName)
                }
            }
        }
    }
}

// Rating Card Component
struct RatingCardView: View {
    let entry: HistoryEntry
    @Binding var userRating: Int
    @Binding var userComment: String
    let viewModel: HistoryViewModel
    let dismiss: DismissAction
    
    var body: some View {
        PlayfulFilterCard(
            title: "評価とコメント",
            icon: "star.fill"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("この決定はいかがでしたか？")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    InteractiveStarRatingView(rating: $userRating)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("コメント（任意）")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    TextField("感想をお聞かせください...", text: $userComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(6)
                }
                
                Button(action: {
                    viewModel.updateRating(for: entry, rating: Double(userRating))
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                        Text("評価を保存")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [themeOrange, themeTeal]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: themeOrange.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .disabled(userRating == 0)
                .opacity(userRating == 0 ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: userRating)
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                )
        }
    }
}



extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 H:mm"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// Global Rating View that shows all user ratings and comments
struct RatingSheetView: View {
    let entry: HistoryEntry
    let onSave: (HistoryEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var userRating: Double = 0.0
    @State private var userComment: String = ""
    @State private var averageRating: Double = 0.0
    @State private var ratingCount: Int = 0
    @State private var globalRatings: [GlobalRating] = []
    @State private var isLoadingGlobalRatings = true {
        didSet {
            print("🔥 RatingSheetView: isLoadingGlobalRatings changed to: \(isLoadingGlobalRatings)")
        }
    }
    @State private var selectedTab: RatingTab = .community
    
    init(entry: HistoryEntry, onSave: @escaping (HistoryEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        print("🔥 RatingSheetView: init called for entry: \(entry.displayName), ID: \(entry.id), Type: \(entry.resultType)")
    }
    
    enum RatingTab: CaseIterable {
        case community, myRating
        
        var title: String {
            switch self {
            case .community: return "みんなの評価"
            case .myRating: return "あなたの評価"
            }
        }
    }
    
    var itemType: String {
        switch entry.resultType {
        case "recipe": return "recipe"
        case "restaurant": return "restaurant"
        case "eatingOutMeal": return "recipe" // Treat eating out meals as recipes
        default: return "recipe"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text(entry.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Tab Selector
                    HStack(spacing: 0) {
                        ForEach(RatingTab.allCases, id: \.self) { tab in
                            Button(action: {
                                print("🔥 RatingSheetView: Tab selected: \(tab)")
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Text(tab.title)
                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedTab == tab ? themeTeal : .gray)
                                    
                                    Rectangle()
                                        .fill(selectedTab == tab ? themeTeal : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                .background(Color(.systemBackground))
                
                // Content based on selected tab
                ScrollView {
                    Group {
                        if selectedTab == .community {
                            communityRatingsView
                                .onAppear {
                                    print("🔥 RatingSheetView: Showing community ratings view")
                                }
                        } else {
                            myRatingView
                                .onAppear {
                                    print("🔥 RatingSheetView: Showing my rating view")
                                }
                        }
                    }
                    .frame(minHeight: 300) // Ensure minimum height to prevent blank view
                }
            }
            .navigationTitle("評価")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing:
                Button("閉じる") {
                    print("🔥 RatingSheetView: Close button tapped")
                    dismiss()
                }
            )
        }
        .onAppear {
            print("🔥 RatingSheetView: onAppear triggered for: \(entry.displayName)")
            print("🔥 RatingSheetView: Entry details - ID: \(entry.id), Type: \(entry.resultType), ResultID: \(entry.resultId)")
            print("🔥 RatingSheetView: Current rating: \(entry.rating ?? 0.0), Comment: \(entry.userComment ?? "none")")
            print("🔥 RatingSheetView: Selected tab: \(selectedTab)")
            
            userRating = entry.rating ?? 0.0
            userComment = entry.userComment ?? ""
            
            print("🔥 RatingSheetView: Setting loading state to true")
            // Force loading state first, then load after short delay to ensure view is ready
            isLoadingGlobalRatings = true
            print("🔥 RatingSheetView: isLoadingGlobalRatings: \(isLoadingGlobalRatings)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔥 RatingSheetView: Starting loadGlobalRatings after 0.1s delay")
                loadGlobalRatings()
            }
        }
    }
    
    private var communityRatingsView: some View {
        VStack(spacing: 0) {
            // Add top spacing from tabs
            Color.clear.frame(height: 20)
            
            // Average Rating Summary with improved design
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    // Header with icon
                    HStack(spacing: 8) {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundColor(themeTeal)
                        
                        Text("みんなの評価")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    // Rating display with better styling
                    VStack(spacing: 12) {
                        // Large average rating
                        HStack(spacing: 16) {
                            // Left side - Stars
                            VStack(spacing: 6) {
                                HStack(spacing: 3) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
                                            .foregroundColor(.orange)
                                            .font(.title2)
                                    }
                                }
                                
                                Text("\(ratingCount)件の評価")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Right side - Numeric rating
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f", averageRating))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(themeOrange)
                                
                                Text("5点満点")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Divider
                        Rectangle()
                            .fill(themeTeal.opacity(0.2))
                            .frame(height: 1)
                            .padding(.horizontal)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(.systemBackground),
                                    themeTeal.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            themeTeal.opacity(0.3),
                                            themeOrange.opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: themeTeal.opacity(0.1),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
            }
            .padding(.horizontal, 20)
            
            // Individual Ratings List with spacing
            VStack(spacing: 0) {
                // Add spacing between summary and list
                Color.clear.frame(height: 24)
                
                if isLoadingGlobalRatings {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(themeTeal)
                        Text("評価を読み込み中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .onAppear {
                        print("🔄 Showing loading view - isLoading: \(isLoadingGlobalRatings)")
                    }
                } else if globalRatings.isEmpty {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 48))
                                .foregroundColor(themeTeal.opacity(0.6))
                            
                            Text("まだ評価がありません")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("最初の評価をしてみませんか？")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            selectedTab = .myRating
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.subheadline)
                                Text("評価する")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [themeTeal, themeOrange]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: themeTeal.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 40)
                    .onAppear {
                        print("🔄 Showing empty state - isLoading: \(isLoadingGlobalRatings), ratingsCount: \(globalRatings.count)")
                    }
                } else {
                    // Header for individual ratings
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.subheadline)
                                .foregroundColor(themeOrange)
                            
                            Text("ユーザーレビュー")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Text("\(globalRatings.count)件")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(globalRatings) { rating in
                            GlobalRatingCard(rating: rating)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 20)
                    .onAppear {
                        print("🔄 Showing ratings list - isLoading: \(isLoadingGlobalRatings), ratingsCount: \(globalRatings.count)")
                    }
                }
            }
        }
        .onAppear {
            print("🔥 RatingSheetView: communityRatingsView accessed - isLoading: \(isLoadingGlobalRatings), ratingsCount: \(globalRatings.count)")
        }
    }
    
    private var myRatingView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Text("あなたの評価")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    StarRatingView(
                    rating: userRating,
                        maxRating: 5,
                        size: 32,
                        isInteractive: true,
                        onRatingChanged: { newRating in
                        print("🔥 RatingSheetView: User rating changed to: \(newRating)")
                        userRating = newRating
                        }
                    )
                }
            .padding()
                
                // Comment
                VStack(alignment: .leading, spacing: 12) {
                    Text("コメント（任意）")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Group {
                        if #available(iOS 16.0, *) {
                        TextField("感想を書いてください...", text: $userComment, axis: .vertical)
                                .lineLimit(3...6)
                        } else {
                        TextField("感想を書いてください...", text: $userComment)
                                .lineLimit(3)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            .padding(.horizontal)
                
                Spacer()
                
                // Save Button
                Button(action: {
                saveRating()
                }) {
                    Text("評価を保存")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [themeOrange, themeTeal]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            .disabled(userRating == 0)
            .opacity(userRating == 0 ? 0.6 : 1.0)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .onAppear {
            print("🔥 RatingSheetView: myRatingView accessed - userRating: \(userRating), userComment: \(userComment)")
        }
    }
    
    private func loadGlobalRatings() {
        print("🔄 Loading global ratings for itemId: \(entry.resultId), itemType: \(itemType)")
        
        // Ensure loading state is set and reset data states
        DispatchQueue.main.async {
            self.isLoadingGlobalRatings = true
            self.averageRating = 0.0
            self.ratingCount = 0
            self.globalRatings = []
            print("🔄 Reset states and confirmed loading state: \(self.isLoadingGlobalRatings)")
        }
        
        let group = DispatchGroup()
        var tempAverage: Double = 0.0
        var tempCount: Int = 0
        var tempRatings: [GlobalRating] = []
        
        // Load average rating
        group.enter()
        FirebaseService.shared.getAverageRating(itemId: entry.resultId, itemType: itemType) { average, count, error in
            if let error = error {
                print("❌ Failed to load average rating: \(error.localizedDescription)")
            } else {
                print("✅ Loaded average rating: \(average) (\(count) ratings)")
                tempAverage = average
                tempCount = count
            }
            group.leave()
        }
        
        // Load individual ratings with comments
        group.enter()
        FirebaseService.shared.getGlobalRatings(itemId: entry.resultId, itemType: itemType) { ratings, error in
            if let error = error {
                print("❌ Failed to load global ratings: \(error.localizedDescription)")
            } else if let ratings = ratings {
                print("✅ Loaded \(ratings.count) individual ratings")
                tempRatings = ratings.sorted { $0.timestamp > $1.timestamp }
            } else {
                print("⚠️ No global ratings found")
                tempRatings = []
            }
            group.leave()
        }
        
        // Update UI once when both requests complete
        group.notify(queue: .main) {
            print("✅ Updating UI with loaded data: average=\(tempAverage), count=\(tempCount), ratings=\(tempRatings.count)")
            self.averageRating = tempAverage
            self.ratingCount = tempCount
            self.globalRatings = tempRatings
            self.isLoadingGlobalRatings = false
            print("✅ Finished loading global ratings - UI updated. Loading: \(self.isLoadingGlobalRatings), Ratings: \(self.globalRatings.count)")
        }
    }
    
    private func saveRating() {
        // Save user rating
        var updatedEntry = entry
        updatedEntry.rating = userRating
        updatedEntry.userComment = userComment
        onSave(updatedEntry)
        
        // Save global rating
        if let userId = AuthService.shared.currentUser?.id {
            FirebaseService.shared.saveGlobalRating(
                itemId: entry.resultId, 
                itemType: itemType, 
                userId: userId, 
                rating: userRating,
                comment: userComment
            ) { error in
                if error == nil {
                    DispatchQueue.main.async {
                        // Refresh global ratings
                        self.loadGlobalRatings()
                    }
                }
            }
        }
        
                    dismiss()
                }
}

// Global Rating Card Component
struct GlobalRatingCard: View {
    let rating: GlobalRating
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                // User avatar with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [themeTeal.opacity(0.8), themeOrange.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(rating.userId.prefix(1)).uppercased())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .shadow(color: themeTeal.opacity(0.3), radius: 4, x: 0, y: 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("ユーザー")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(formatDate(rating.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Rating stars with better styling
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(rating.rating) ? "star.fill" : "star")
                                .foregroundColor(star <= Int(rating.rating) ? .orange : Color(.systemGray4))
                                .font(.system(size: 14))
                        }
                        
                        Text(String(format: "%.1f", rating.rating))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                }
            }
            
            // Comment with better styling
            if !rating.comment.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(themeTeal.opacity(0.15))
                        .frame(height: 1)
                    
                    Text(rating.comment)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeTeal.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}



struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(selectedTab: .constant(1))
    }
}

// Recipe Detail Loading View for History
struct RecipeDetailLoadingView: View {
    let recipeId: String
    let servings: Int
    @State private var recipe: Recipe?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("レシピを読み込み中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let recipe = recipe {
                NavigationView {
                    RecipeDetailView(recipe: recipe, initialServings: servings)
                        .navigationTitle("レシピ詳細")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarItems(trailing:
                            Button("閉じる") {
                                dismiss()
                            }
                        )
                        .onDisappear {
                            // Refresh history when returning from recipe detail
                            // This ensures that any rating changes are reflected
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshHistory"), object: nil)
                            }
                        }
                }
            } else {
                NavigationView {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("レシピが見つかりません")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("閉じる") {
                            dismiss()
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(themeOrange)
                        .cornerRadius(12)
                    }
                    .padding()
                    .navigationTitle("レシピ詳細")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(trailing:
                        Button("閉じる") {
                            dismiss()
                        }
                    )
                }
            }
        }
        .onAppear {
            loadRecipe()
        }
    }
    
    private func loadRecipe() {
        isLoading = true
        errorMessage = nil
        
        RecipeService.shared.fetchRecipe(id: recipeId) { recipe in
            DispatchQueue.main.async {
                self.isLoading = false
                if let recipe = recipe {
                    self.recipe = recipe
                } else {
                    self.errorMessage = "レシピを読み込めませんでした"
                }
            }
        }
    }
} 