import Foundation
import CoreBluetooth

/// Detection is static (`CBManager.authorization`) and never powers on the radio.
/// Requesting requires instantiating a `CBCentralManager`, which triggers the
/// system prompt — we hold it alive until the delegate reports authorization, then
/// release it. We never scan for peripherals.
final class BluetoothAuthorizer: NSObject, CBCentralManagerDelegate {
    static let shared = BluetoothAuthorizer()

    private var central: CBCentralManager?
    private var pending: ((PermissionStatus) -> Void)?

    /// Current authorization without instantiating a central or powering the radio.
    static var status: PermissionStatus {
        PermissionStatus.from(CBManager.authorization)
    }

    /// Requests Bluetooth authorization. If already decided, routes denied/
    /// restricted to System Settings and reports the current status.
    @MainActor
    func request(_ completion: @escaping (PermissionStatus) -> Void) {
        let current = CBManager.authorization
        guard current == .notDetermined else {
            if current == .denied || current == .restricted {
                SystemSettingsLink.open(.bluetooth)
            }
            completion(.from(current))
            return
        }
        pending = completion
        // Instantiating a central (power alert suppressed) triggers the TCC prompt.
        // queue: nil → delegate callbacks arrive on the main queue.
        central = CBCentralManager(
            delegate: self,
            queue: nil,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let auth = CBManager.authorization
        guard auth != .notDetermined, let completion = pending else { return }
        pending = nil
        completion(.from(auth))
        self.central = nil // release; we never scan
    }
}
