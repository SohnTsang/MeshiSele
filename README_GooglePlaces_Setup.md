# Google Places API Setup Guide for MeshiSele

This guide walks you through setting up Google Places API to replace MapKit for more accurate restaurant searches.

## 🎯 Benefits of Google Places API

### **Advantages over MapKit:**
- **🔍 Superior search accuracy** for specific meal types (e.g., "ラーメン", "焼肉")
- **📊 Rich restaurant data** (ratings, reviews, photos, price levels)
- **🌏 Better Japanese language support** and local restaurant knowledge
- **🎯 Advanced filtering** (price level, rating, opening hours)
- **📸 High-quality photos** directly from Google Maps

### **Cost Comparison:**
- **Free tier**: $200/month credit = ~6,250 restaurant searches
- **Paid usage**: $32 per 1,000 text searches
- **For typical usage**: Likely **FREE** unless >6,000 searches/month

## 🚀 Setup Instructions

### **Step 1: Google Cloud Console Setup**

1. **Create Project**
   ```
   Go to: https://console.cloud.google.com
   → New Project or select existing
   → Note your Project ID
   ```

2. **Enable Required APIs**
   ```
   APIs & Services → Library → Search for:
   ✅ Places API (New) - Primary API
   ✅ Places API - Legacy compatibility
   ✅ Geocoding API - Optional for address conversion
   ```

3. **Create API Key**
   ```
   APIs & Services → Credentials → Create Credentials → API Key
   → Copy the generated key
   ```

4. **Secure Your API Key**
   ```
   Edit API Key → Application restrictions:
   ✅ iOS apps
   ✅ Bundle ID: com.yourcompany.meshisele
   
   API restrictions:
   ✅ Places API (New)
   ✅ Places API  
   ✅ Geocoding API (if enabled)
   ```

### **Step 2: Add API Key to App**

1. **Open** `MeshiSele/Constants/APIKeys.swift`

2. **Replace the placeholder** with your actual API key:
   ```swift
   static let googlePlacesAPIKey = "YOUR_ACTUAL_API_KEY_HERE"
   ```

3. **For development**, optionally set debug key:
   ```swift
   static let debugGooglePlacesAPIKey: String? = "YOUR_DEBUG_KEY"
   ```

### **Step 3: Build and Test**

1. **Build the app** to ensure no compilation errors
2. **Test restaurant search** - app will automatically use Google Places API when configured
3. **Check logs** for "Using Google Places API for enhanced search" messages

## 🔧 How It Works

### **Automatic Fallback System**
```swift
// App automatically chooses the best available service:
if APIKeys.isGooglePlacesAPIKeyConfigured {
    // ✅ Use Google Places API (superior results)
    GooglePlacesService.shared.searchRestaurantsForMeal(...)
} else {
    // 🔄 Fallback to MapKit (basic functionality)
    PlaceService.shared.fetchRestaurantsForMeal(...)
}
```

### **Enhanced Search Queries**
Google Places API builds optimized queries:
```
Input: "ラーメン" + "和食"
→ Query: "ラーメン 和食 restaurant"
→ Results: Highly relevant ramen restaurants
```

### **Smart Cost Optimization**
- **Field masking**: Only requests needed data fields
- **Result limiting**: Max 20 results per request
- **Strategic caching**: Reduces redundant API calls

## 📊 Monitoring Usage & Costs

### **Google Cloud Console Monitoring**
```
Navigation: APIs & Services → Dashboard
→ View API usage graphs
→ Set billing alerts at $50, $100, $150
→ Monitor quota usage
```

### **Expected Usage Pattern**
- **Light users**: <100 searches/month = FREE
- **Regular users**: 100-1000 searches/month = FREE  
- **Heavy users**: 1000-6000 searches/month = FREE
- **Beyond 6k**: ~$32 per additional 1,000 searches

## 🔍 Search Quality Improvements

### **Meal-Specific Keywords**
| Input | MapKit Result | Google Places Result |
|-------|---------------|---------------------|
| "ラーメン" | Generic restaurants | Specific ramen shops |
| "焼肉" | Mixed results | Yakiniku specialists |
| "寿司" | Broad matches | Authentic sushi bars |

### **Enhanced Filtering**
- ✅ **Budget-aware**: Price level filtering
- ✅ **Quality focus**: Minimum rating (3.0+)
- ✅ **Type strict**: Restaurant-only results
- ✅ **Relevance ranking**: Best matches first

## ⚠️ Important Notes

### **API Key Security**
- ✅ **Never commit** real API keys to version control
- ✅ **Use restrictions** to limit usage to your iOS app
- ✅ **Monitor usage** regularly for unexpected spikes
- ✅ **Rotate keys** periodically for security

### **Fallback Behavior**
- App **gracefully falls back** to MapKit if Google Places fails
- **No user disruption** - seamless experience
- Error messages guide users to retry or adjust search

### **Development vs Production**
- **Debug builds**: Can use separate test API key
- **Production builds**: Uses main API key
- **Environment detection**: Automatic switching

## 🛠️ Troubleshooting

### **"No restaurants found" Error**
```
Check:
1. API key configured correctly in APIKeys.swift
2. Places API (New) enabled in Google Cloud
3. API key restrictions allow your iOS bundle ID
4. Billing account active (even for free tier)
```

### **Build Errors**
```
1. Clean build folder (Cmd+Shift+K)
2. Ensure all files added to Xcode project
3. Check import statements
4. Verify GooglePlacesService.swift is in project
```

### **Network Issues**
```
Check:
1. Device has internet connection
2. API quotas not exceeded
3. No network restrictions blocking Google APIs
4. Check error logs for specific API responses
```

## 📱 User Experience Improvements

### **Before (MapKit)**
- ❌ Generic "restaurant" searches
- ❌ Limited filtering options  
- ❌ Inconsistent results for Japanese food terms
- ❌ No ratings or price information

### **After (Google Places API)**
- ✅ Meal-specific restaurant discovery
- ✅ Rich metadata (ratings, photos, prices)
- ✅ Superior Japanese language understanding
- ✅ More accurate location-based results

## 🔄 Gradual Migration Plan

### **Phase 1: Parallel Operation** ✅ COMPLETE
- Google Places API integrated alongside MapKit
- Automatic selection based on API key availability
- Full backward compatibility maintained

### **Phase 2: User Testing** (Current)
- Add your Google Places API key
- Test restaurant search functionality
- Monitor search result quality

### **Phase 3: Optimization** (Next)
- Fine-tune search queries based on usage patterns
- Implement result caching for cost reduction
- Add advanced filtering options

### **Phase 4: Full Migration** (Future)
- Consider making Google Places primary service
- Keep MapKit as fallback for offline scenarios
- Continuous monitoring and improvement

## 📞 Support

If you encounter issues:
1. **Check logs** for detailed error messages
2. **Verify setup** against this guide
3. **Test with simple searches** first
4. **Monitor Google Cloud Console** for API issues

The integration is designed to be **robust and user-friendly** - your app will work regardless of Google Places API availability, but will provide significantly better results when properly configured.

---

**Ready to get started? Just add your Google Places API key to `APIKeys.swift` and enjoy enhanced restaurant discovery! 🍜🎉** 