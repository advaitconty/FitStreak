import Foundation
import CoreLocation
import Combine

class NewLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    private var previousLocation: CLLocation?
    private var totalDistance: CLLocationDistance = 0.0
    private var isUpdating = false

    @Published var lastLocation: CLLocation?
    @Published var locationAccessDenied = false

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.requestWhenInUseAuthorization()
    }

    func startLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationAccessDenied = true
            return
        }
        totalDistance = 0.0
        previousLocation = nil
        locationManager.startUpdatingLocation()
        isUpdating = true
    }

    func pauseLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isUpdating = false
    }

    func resumeLocationUpdates() {
        guard CLLocationManager.locationServicesEnabled() else {
            locationAccessDenied = true
            return
        }
        locationManager.startUpdatingLocation()
        isUpdating = true
    }

    func getTotalDistanceTravelled() -> Double {
        return totalDistance / 1000.0 // convert meters to kilometers
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isUpdating else { return }

        for location in locations {
            guard location.horizontalAccuracy >= 0 else { continue }

            if let previous = previousLocation {
                let distance = location.distance(from: previous)
                if distance > 0.5 { // Ignore tiny jumps/noise
                    totalDistance += distance
                }
            }
            previousLocation = location
            lastLocation = location
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            locationAccessDenied = true
        }
    }
}
