import Foundation
import CoreLocation

/// Owns a single long-lived `CLLocationManager` so location authorization can be
/// read synchronously (no per-check instance churn) and requested via the delegate
/// callback. Driven from the main thread (the probe/manager are main-actor driven),
/// so the manager is created on main and its delegate callbacks arrive there.
final class LocationAuthorizer: NSObject, CLLocationManagerDelegate {
    static let shared = LocationAuthorizer()

    private let manager = CLLocationManager()
    private var pending: ((PermissionStatus) -> Void)?

    private override init() {
        super.init()
        manager.delegate = self
    }

    /// Current authorization, read synchronously. Reading the status neither starts
    /// location updates nor shows a prompt.
    var cachedStatus: PermissionStatus {
        PermissionStatus.from(manager.authorizationStatus)
    }

    /// Requests When-In-Use authorization. If the user already decided, routes
    /// denied/restricted to System Settings and reports the current status.
    @MainActor
    func request(_ completion: @escaping (PermissionStatus) -> Void) {
        let current = manager.authorizationStatus
        guard current == .notDetermined else {
            if current == .denied || current == .restricted {
                SystemSettingsLink.open(.location)
            }
            completion(.from(current))
            return
        }
        pending = completion
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        // The delegate fires on assignment too; only resolve a pending request once
        // the user has actually made a decision.
        guard status != .notDetermined, let completion = pending else { return }
        pending = nil
        completion(.from(status))
    }
}
