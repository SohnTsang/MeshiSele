# MeshiSele (メシセレ)

A Japanese food recommendation iOS app that helps users discover recipes and restaurants based on their preferences, ingredients, and dietary requirements.

## Features

### Recipe Recommendations
- **Smart Filtering**: Filter by cuisine type (Japanese, Western, Chinese, etc.), diet preferences (vegetarian, meat-based), budget, and cooking time
- **Ingredient-Based Search**: Input available ingredients to find matching recipes
- **Autocomplete Ingredient Input**: Dynamic suggestions based on recipe database
- **Comprehensive Recipe Data**: Over 200+ Japanese recipes with detailed instructions, nutrition info, and cost estimates

### Restaurant Discovery
- **Location-Based**: Find nearby restaurants using device location
- **Google Integration**: Restaurant ratings, photos, and reviews
- **Cuisine Filtering**: Filter restaurants by cuisine type and price range
- **Detailed Information**: Opening hours, contact info, and directions

### User Experience
- **Bilingual Support**: Japanese and English localization
- **History Tracking**: Keep track of previously selected recipes and restaurants
- **Personalized Settings**: Save dietary preferences and common ingredients
- **Modern UI**: Clean, intuitive interface with smooth animations

## Technical Stack

- **Platform**: iOS (SwiftUI)
- **Backend**: Firebase Firestore
- **Maps**: Google Maps SDK
- **Location**: Core Location
- **Architecture**: MVVM pattern
- **Dependencies**: Firebase, Google Maps, Google Places

## Setup

1. Clone the repository
2. Open `MeshiSele.xcodeproj` in Xcode
3. Install dependencies (Firebase SDK will be automatically resolved)
4. Add your `GoogleService-Info.plist` file to the project
5. Configure Google Maps API key in `APIKeys.swift`
6. Build and run on iOS Simulator or device

## Project Structure

```
MeshiSele/
├── Models/          # Data models (Recipe, EatingOutMeal, etc.)
├── Views/           # SwiftUI views
├── ViewModels/      # View models for MVVM
├── Services/        # Business logic and API services
├── Components/      # Reusable UI components
├── Data/            # Local JSON data files
├── Extensions/      # Swift extensions
└── Constants/       # App constants and configuration
```

## Key Components

- **HomeView**: Main interface for recipe and restaurant selection
- **SettingsView**: User preferences and ingredient management
- **HistoryView**: Previously selected items
- **RecipeService**: Recipe fetching and filtering logic
- **EatingOutMealService**: Restaurant discovery and management
- **IngredientService**: Ingredient autocomplete and validation

## Data Sources

- **Local JSON**: Backup recipe database with 200+ recipes
- **Firebase**: Primary database for recipes and user data
- **Google Places**: Restaurant information and reviews

## License

This project is private and proprietary.

## Development

Developed with modern iOS development practices including:
- SwiftUI for declarative UI
- Combine for reactive programming
- Firebase for backend services
- MVVM architecture pattern
- Localization support 