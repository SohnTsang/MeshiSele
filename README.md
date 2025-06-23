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

### Prerequisites
1. **Xcode 15.0+** with iOS 15.0+ deployment target
2. **Firebase Project** with Firestore and Authentication enabled
3. **Google Cloud Project** with Places API enabled

### 1. Clone the Repository
```bash
git clone https://github.com/SohnTsang/MeshiSele.git
cd MeshiSele
```

### 2. Configure API Keys
1. Copy the template file:
   ```bash
   cp MeshiSele/Constants/APIKeys.swift.template MeshiSele/Constants/APIKeys.swift
   ```
2. Edit `MeshiSele/Constants/APIKeys.swift` and replace `YOUR_GOOGLE_PLACES_API_KEY_HERE` with your actual Google Places API key
3. Get your API key from [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
4. Enable the following APIs:
   - Places API
   - Maps SDK for iOS
   - Geocoding API

### 3. Configure Firebase
1. Copy the template file:
   ```bash
   cp MeshiSele/GoogleService-Info.plist.template MeshiSele/GoogleService-Info.plist
   ```
2. Download your actual `GoogleService-Info.plist` from [Firebase Console](https://console.firebase.google.com/)
3. Replace the template file with your downloaded Firebase configuration

### 4. Build and Run
1. Open `MeshiSele.xcodeproj` in Xcode
2. Install dependencies (Firebase SDK will be automatically resolved)
3. Build and run on iOS Simulator or device

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

## Security

⚠️ **Important**: Never commit sensitive files to version control!

The following files contain sensitive information and are excluded from the repository:
- `MeshiSele/Constants/APIKeys.swift` - Contains Google API keys
- `MeshiSele/GoogleService-Info.plist` - Contains Firebase configuration
- `MeshiSele/Scripts/service-account-key.json` - Contains Firebase service account credentials

Template files are provided for setup guidance.

## License

This project is private and proprietary.

## Development

Developed with modern iOS development practices including:
- SwiftUI for declarative UI
- Combine for reactive programming
- Firebase for backend services
- MVVM architecture pattern
- Localization support 