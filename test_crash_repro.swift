import Foundation
import Firebase
// import GoogleMobileAds // This should be commented out but might still be linked

class CrashReproductionTest {
    static func testFirebaseInitialization() {
        print("🧪 Testing Firebase initialization...")
        
        // This might trigger the crash if there are initialization issues
        DispatchQueue.global(qos: .background).async {
            // Simulate background Firebase operations
            for i in 1...10 {
                print("Background operation \(i)")
                Thread.sleep(forTimeInterval: 0.1)
                
                // Try to access Firebase on background thread (potential crash point)
                if let app = FirebaseApp.app() {
                    print("Firebase app exists: \(app)")
                } else {
                    print("Firebase app is nil - potential crash point")
                }
            }
        }
        
        // Give background thread time to potentially crash
        Thread.sleep(forTimeInterval: 2.0)
        print("✅ Firebase initialization test completed without crash")
    }
    
    static func testLocationManagerCrash() {
        print("🧪 Testing LocationManager potential crash...")
        
        // Create multiple location managers rapidly (potential crash scenario)
        for i in 1...5 {
            DispatchQueue.global(qos: .background).async {
                let manager = LocationManager.shared
                print("Created LocationManager instance \(i)")
                
                // Rapidly request location updates
                manager.requestOneTimeLocation()
            }
        }
        
        Thread.sleep(forTimeInterval: 1.0)
        print("✅ LocationManager test completed")
    }
}
