import Foundation
import CoreLocation
import Combine
import UIKit

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    
    // CRITICAL: All operations on main queue to prevent crashes
    private let stateQueue = DispatchQueue.main
    
    override init() {
        super.init()
        
        print("📍📍📍 LocationManager: Initializing...")
        
        // CRITICAL: Configure location manager safely
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                print("📍 LocationManager: Init - self is nil")
                return 
            }
            
            print("📍 LocationManager: Configuring location manager...")
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            self.locationManager.distanceFilter = 100 // Only update when moved 100 meters
            
            // Set initial authorization status
            self.authorizationStatus = self.locationManager.authorizationStatus
            print("📍 LocationManager: Initial authorization status: \(self.authorizationStatus.rawValue)")
            
            print("📍📍📍 LocationManager: Initialization complete")
        }
    }
    
    deinit {
        print("📍 LocationManager: Deinitializing...")
        
        // CRITICAL: Ensure all operations are cancelled safely
        DispatchQueue.main.sync {
            locationManager.delegate = nil
            locationManager.stopUpdatingLocation()
        }
        
        print("📍 LocationManager: Deinitialized safely")
    }
    
    // CRITICAL: All property setters use main queue only
    private func setCurrentLocation(_ location: CLLocation?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLocation = location
        }
    }
    
    private func setAuthorizationStatus(_ status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.authorizationStatus = status
        }
    }
    
    private func setLocationError(_ error: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.locationError = error
        }
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch self.locationManager.authorizationStatus {
            case .notDetermined:
                print("📍 LocationManager: Requesting location permission...")
                self.locationManager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                print("📍 LocationManager: Location permission denied")
                self.setLocationError("位置情報の利用が許可されていません")
            case .authorizedWhenInUse, .authorizedAlways:
                print("📍 LocationManager: Location permission already granted")
                self.startLocationUpdates()
            @unknown default:
                print("📍 LocationManager: Unknown authorization status")
                break
            }
        }
    }
    
    func startLocationUpdates() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.locationManager.authorizationStatus == .authorizedWhenInUse ||
                  self.locationManager.authorizationStatus == .authorizedAlways else {
                print("📍 LocationManager: Location permission not granted")
                return
            }
            
            print("📍 LocationManager: Starting location updates...")
            
            // Set better accuracy for initial location
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            
            // Try both methods for better success rate
            self.locationManager.startUpdatingLocation()
            
            // Also try one-time request
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.locationManager.requestLocation()
            }
        }
    }
    
    func stopLocationUpdates() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("📍 LocationManager: Stopping location updates...")
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    func requestOneTimeLocation() {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.locationManager.authorizationStatus == .authorizedWhenInUse ||
                  self.locationManager.authorizationStatus == .authorizedAlways else {
                print("📍 LocationManager: Permission not granted for one-time location")
                self.requestLocationPermission()
                return
            }
            
            print("📍 LocationManager: Requesting one-time location...")
            // Try both methods to increase success rate
            self.locationManager.requestLocation()
            
            // Also start updating location with timeout
            self.locationManager.startUpdatingLocation()
            
            // Stop location updates after 10 seconds to prevent battery drain
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                guard let self = self else { return }
                print("📍 LocationManager: Stopping location updates after timeout")
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
    
    func clearError() {
        setLocationError(nil)
    }
    
    // MARK: - Computed Properties
    
    var isLocationAvailable: Bool {
        return currentLocation != nil
    }
    
    var isLocationPermissionGranted: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var locationStatusMessage: String {
        switch authorizationStatus {
        case .notDetermined:
            return "位置情報の許可が必要です"
        case .denied, .restricted:
            return "位置情報の利用が許可されていません"
        case .authorizedWhenInUse, .authorizedAlways:
            return isLocationAvailable ? "位置情報を取得済み" : "位置情報を取得中..."
        @unknown default:
            return "位置情報の状態が不明です"
        }
    }
    
    // Get distance between two coordinates
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    // Format distance for display
    func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return String(format: "%.0fm", distance)
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // CRITICAL: Always execute delegate callbacks on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let location = locations.last {
                print("📍 LocationManager: Location updated: \(location.coordinate)")
                self.setCurrentLocation(location)
                self.setLocationError(nil)
                
                // Stop location updates after successful location
                self.locationManager.stopUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let clError = error as? CLError {
                print("📍 LocationManager: CLError: \(clError.code.rawValue) - \(clError.localizedDescription)")
                
                switch clError.code {
                case .locationUnknown:
                    // This is often temporary - don't show error, just keep trying
                    print("📍 LocationManager: Location unknown - will keep trying...")
                    
                    // Set a gentle message instead of an error
                    self.setLocationError(nil) // Clear any previous error
                    
                    // Try requesting location again with a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        guard let self = self else { return }
                        if self.currentLocation == nil {
                            print("📍 LocationManager: Retrying after location unknown...")
                            self.locationManager.requestLocation()
                        }
                    }
                    return
                case .denied:
                    print("📍 LocationManager: Location access denied")
                    self.setLocationError("位置情報の利用が許可されていません。設定から許可してください。")
                case .network:
                    print("📍 LocationManager: Network error")
                    self.setLocationError("ネットワークエラーにより位置情報を取得できません。")
                case .headingFailure:
                    print("📍 LocationManager: Heading failure")
                    self.setLocationError("方位情報を取得できません。")
                case .rangingUnavailable:
                    print("📍 LocationManager: Ranging unavailable")
                    self.setLocationError("位置情報サービスが利用できません。")
                case .rangingFailure:
                    print("📍 LocationManager: Ranging failure")
                    self.setLocationError("位置情報の測定に失敗しました。")
                default:
                    print("📍 LocationManager: Other location error: \(clError.localizedDescription)")
                    self.setLocationError("位置情報の取得に失敗しました: \(clError.localizedDescription)")
                }
            } else {
                print("📍 LocationManager: Non-CLError: \(error.localizedDescription)")
                self.setLocationError("位置情報の取得に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            print("📍 LocationManager: Authorization status changed: \(status.rawValue)")
            self.setAuthorizationStatus(status)
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startLocationUpdates()
            case .denied, .restricted:
                self.setLocationError("位置情報の利用が許可されていません。設定から許可してください。")
                self.stopLocationUpdates()
            case .notDetermined:
                // Waiting for user decision
                break
            @unknown default:
                break
            }
        }
    }
} 