import Foundation
import CoreLocation
import Combine

class NewMotionManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    /// the last raw speed from CLLocation (km/h)
    @Published private(set) var rawSpeed: Double = 0.0
    
    /// the filtered speed you should display (km/h)
    @Published var speed: Double = 0.0
    
    /// current horizontal accuracy (meters)
    @Published var accuracy: CLLocationAccuracy = .greatestFiniteMagnitude
    
    /// below this threshold (meters) we trust the measurement
    private let accuracyThreshold: CLLocationAccuracy = 20
    
    /// smoothing factor for valid measurements (0–1, lower = smoother)
    private let validSmoothing: Double = 0.2
    
    /// decay factor when accuracy is poor (0–1, lower = faster decay)
    private let poorDecay: Double = 0.8

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdates() {
        locationManager.stopUpdatingLocation()
        rawSpeed = 0
        speed = 0
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }

        accuracy = latest.horizontalAccuracy
        
        // CLLocation.speed is in m/s, -1 if invalid
        let measured = latest.speed >= 0 ? latest.speed * 3.6 : 0.0
        rawSpeed = measured
        
        if accuracy <= accuracyThreshold {
            // good signal → smooth toward new measurement
            speed = speed * (1 - validSmoothing) + measured * validSmoothing
        } else {
            // poor signal → decay last known speed
            speed *= poorDecay
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // handle denied/restricted if you like...
    }
}
