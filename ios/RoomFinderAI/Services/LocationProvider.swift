import CoreLocation
import Foundation

/// The device's current position, once, for filling in an address.
///
/// Posting a room happens at the room. The photo's own GPS would be ideal, but
/// `PhotosPicker` deliberately strips location from what it hands back — that
/// metadata is only available to an app holding full photo-library access, and
/// asking for the whole library to read one coordinate is a bad trade. So when
/// a photo carries no location, which is most of the time, this asks the device
/// where it is instead.
///
/// Deliberately one-shot rather than a running location session: nothing here
/// tracks anyone, and a single fix is all an address lookup needs.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var waiting: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        // Street-level is plenty for reverse geocoding, and asking for less
        // precision returns a fix faster and costs less battery.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// The current coordinate, or nil if it is unavailable or refused.
    ///
    /// Never throws and never blocks forever: a refused prompt, airplane mode
    /// or a slow fix all resolve to nil, because a missing address must leave
    /// the rest of the listing intact rather than failing the whole draft.
    func currentCoordinate() async -> CLLocationCoordinate2D? {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // The delegate callback below resumes this once the person answers.
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                authorisationWaiting = continuation
            }
            guard granted else { return nil }
        default:
            break
        }

        return await withTaskGroup(of: CLLocationCoordinate2D?.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    self.waiting = continuation
                    self.manager.requestLocation()
                }
            }
            // A fix can simply never arrive indoors. Give up rather than leave
            // the posting flow waiting on it.
            group.addTask {
                try? await Task.sleep(nanoseconds: 8 * NSEC_PER_SEC)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private var authorisationWaiting: CheckedContinuation<Bool, Never>?

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let continuation = authorisationWaiting else { return }
            authorisationWaiting = nil
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: continuation.resume(returning: true)
            case .notDetermined: authorisationWaiting = continuation   // still deciding
            default: continuation.resume(returning: false)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            let coordinate = locations.last?.coordinate
            waiting?.resume(returning: coordinate)
            waiting = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            waiting?.resume(returning: nil)
            waiting = nil
        }
    }
}
