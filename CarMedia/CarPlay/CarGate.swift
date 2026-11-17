// CarMedia — MIT © 2026 CarMedia contributors (see LICENSE).
// Parked/moving detection adapted from cafari-lite (MIT © rPlayAI).

import CoreLocation
import Foundation

/// Is the car moving? There is no CarPlay API that answers this for a
/// window-scene app, so the answer comes from location speed: above a
/// walking pace for a few consecutive samples counts as driving, and the
/// car screen blanks its video until the speed drops again (audio keeps
/// playing — the same fallback direction the system itself uses for
/// template sessions when the car reports video as unavailable).
///
/// Deliberately conservative in one direction only: if location is refused
/// or unavailable we report "not moving" rather than blocking playback —
/// a gate that cannot measure anything should not pretend it can. The
/// parkedGate feature flag turns the mechanism off entirely.
public final class CarGate: NSObject, CLLocationManagerDelegate {
    public static let shared = CarGate()

    public static let stateChanged = Notification.Name("CarMediaCarGateChanged")
    public private(set) var isMoving = false

    private let manager = CLLocationManager()
    private var running = false
    // About 11 km/h — faster than a pedestrian, slower than driving,
    // above the noise floor of a stationary fix.
    private let movingSpeed: CLLocationSpeed = 3.0
    private let samplesToFlip = 3
    private var agreeing = 0

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = true
    }

    /// Pure hysteresis decision, exposed for unit tests.
    public static func decide(speed: CLLocationSpeed, isMoving: Bool, agreeing: Int,
                              samplesToFlip: Int, threshold: CLLocationSpeed = 3.0)
        -> (flip: Bool, nextAgreeing: Int, nextMoving: Bool)
    {
        guard speed >= 0 else { return (false, agreeing, isMoving) }
        let candidate = speed > threshold
        if candidate == isMoving { return (false, 0, isMoving) }
        let n = agreeing + 1
        if n >= samplesToFlip { return (true, 0, candidate) }
        return (false, n, isMoving)
    }

    public func start() {
        guard !running else { return }
        running = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        EventLog.shared.record(.carplay, "car gate started, authorization=\(manager.authorizationStatus.rawValue)")
    }

    public func stop() {
        guard running else { return }
        running = false
        manager.stopUpdatingLocation()
        setMoving(false)
        EventLog.shared.record(.carplay, "car gate stopped")
    }

    private func setMoving(_ moving: Bool) {
        guard moving != isMoving else { return }
        isMoving = moving
        EventLog.shared.record(.carplay, "car gate: \(moving ? "moving" : "parked")")
        NotificationCenter.default.post(name: CarGate.stateChanged, object: nil)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let speed = locations.last?.speed else { return }
        let result = CarGate.decide(speed: speed, isMoving: isMoving,
                                    agreeing: agreeing, samplesToFlip: samplesToFlip,
                                    threshold: movingSpeed)
        agreeing = result.nextAgreeing
        if result.flip { setMoving(result.nextMoving) }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No fix is not evidence of driving. Leave the state alone.
        EventLog.shared.record(.carplay, "car gate: location error \(error.localizedDescription)")
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        EventLog.shared.record(.carplay, "car gate: authorization now \(manager.authorizationStatus.rawValue)")
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            setMoving(false)
        }
    }
}
