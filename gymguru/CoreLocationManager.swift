import Foundation
import CoreLocation
import Combine

class NewLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    /// Last valid location fix
    @Published var lastLocation: CLLocation?
    /// Whether the user has denied/restricted location access
    @Published var locationAccessDenied: Bool = false
    /// Current GPS horizontal accuracy (in meters)
    @Published var accuracy: CLLocationAccuracy = .greatestFiniteMagnitude

    /// Total distance travelled (in meters)
    private var totalDistance: CLLocationDistance = 0.0
    /// The last “good” location we used for distance calc
    private var previousLocation: CLLocation?

    /// Only accept fixes with ≤ this accuracy (m)
    private let accuracyThreshold: CLLocationAccuracy = 20
    /// Only count movement ≥ this distance (m) to avoid jitter
    private let distanceFilterMin: CLLocationDistance = 5

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // we’ll filter in delegate, so accept all updates
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.requestWhenInUseAuthorization()
    }

    /// Call when user taps “Play”; resets state
    func startLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationAccessDenied = true
            return
        }
        totalDistance = 0
        previousLocation = nil
        lastLocation = nil
        accuracy = .greatestFiniteMagnitude
        locationManager.startUpdatingLocation()
    }

    /// Call when user taps “Pause”
    func pauseLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }

    /// Call when user taps “Play” again
    func resumeLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationAccessDenied = true
            return
        }
        locationManager.startUpdatingLocation()
    }

    /// Distance in **kilometres**
    func getTotalDistanceTravelled() -> Double {
        return totalDistance / 1000.0
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            locationAccessDenied = true
        default:
            locationAccessDenied = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations {
            // 1) Update published accuracy
            accuracy = loc.horizontalAccuracy

            // 2) Discard poor fixes
            guard loc.horizontalAccuracy > 0,
                  loc.horizontalAccuracy <= accuracyThreshold else {
                continue
            }

            // 3) If we have a previous good fix, measure real movement
            if let last = previousLocation {
                let delta = loc.distance(from: last)
                if delta >= distanceFilterMin {
                    totalDistance += delta
                    previousLocation = loc
                }
            } else {
                // first good fix
                previousLocation = loc
            }

            // 4) Always update lastLocation for UI centering, map overlays, etc.
            lastLocation = loc
        }
    }
}
