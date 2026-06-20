import Foundation
import UserNotifications

/// Notifications have no synchronous status API — only `getNotificationSettings`.
/// We cache the last-known status (read synchronously by the probe) and refresh it
/// asynchronously. `UNUserNotificationCenter.current()` requires a real app bundle,
/// so we degrade to `.unknown` for unbundled processes (unit tests, `swift run`).
final class NotificationAuthorizer {
    static let shared = NotificationAuthorizer()

    private let lock = NSLock()
    private var _cachedStatus: PermissionStatus = .unknown

    /// Last fetched status, read synchronously. Starts `.unknown` until the first
    /// async refresh completes; the manager's poll keeps it current.
    var cachedStatus: PermissionStatus {
        lock.lock(); defer { lock.unlock() }
        return _cachedStatus
    }

    private func store(_ status: PermissionStatus) {
        lock.lock(); _cachedStatus = status; lock.unlock()
    }

    /// A real bundle is required; `UNUserNotificationCenter.current()` crashes
    /// without one.
    private var hasBundle: Bool { Bundle.main.bundleIdentifier != nil }

    /// Asynchronously fetches the current authorization, updates the cache, and
    /// calls back on the main thread.
    func refreshStatus(_ completion: ((PermissionStatus) -> Void)? = nil) {
        guard hasBundle else {
            store(.unknown)
            DispatchQueue.main.async { completion?(.unknown) }
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = PermissionStatus.from(settings.authorizationStatus)
            self?.store(status)
            DispatchQueue.main.async { completion?(status) }
        }
    }

    /// Requests authorization, then re-reads settings for the true resulting status.
    func request(_ completion: @escaping (PermissionStatus) -> Void) {
        guard hasBundle else { completion(.unknown); return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
                guard let self else { DispatchQueue.main.async { completion(.unknown) }; return }
                self.refreshStatus(completion)
            }
    }
}
