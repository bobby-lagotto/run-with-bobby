import Foundation
import CoreLocation
import Combine

@MainActor
final class RunSessionController: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var distanceKm: Double = 0
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var authorizationDenied = false

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var startedAt: Date?
    private var timer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .fitness
        locationManager.distanceFilter = 5
    }

    func start() {
        distanceKm = 0
        elapsedSeconds = 0
        lastLocation = nil
        startedAt = Date()
        isRunning = true
        authorizationDenied = false

        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
            }
        }
    }

    func stop() -> (distanceKm: Double, durationMinutes: Int) {
        locationManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        isRunning = false
        let minutes = max(1, Int((Double(elapsedSeconds) / 60.0).rounded()))
        return (distanceKm, minutes)
    }

    func reset() {
        distanceKm = 0
        elapsedSeconds = 0
        lastLocation = nil
        startedAt = nil
        isRunning = false
    }
}

extension RunSessionController: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            authorizationDenied = status == .denied || status == .restricted
            if status == .authorizedWhenInUse || status == .authorizedAlways, isRunning {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard isRunning else { return }
            for location in locations where location.horizontalAccuracy > 0 && location.horizontalAccuracy < 40 {
                if let lastLocation {
                    distanceKm += location.distance(from: lastLocation) / 1000
                }
                lastLocation = location
            }
        }
    }
}
