import Combine
import Foundation
import Network

/// Publishes connectivity so the shell can show a real offline screen instead
/// of WebKit's "Safari cannot open the page", which looks like the app broke.
@MainActor
final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    @Published private(set) var isOnline = true
    @Published private(set) var isExpensive = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.roomfinderai.network")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let online = path.status == .satisfied
                // Only publish real transitions: NWPathMonitor fires on any
                // interface change, and republishing the same value would
                // rebuild every tab's view body for nothing.
                if online != self.isOnline { self.isOnline = online }
                if path.isExpensive != self.isExpensive { self.isExpensive = path.isExpensive }
            }
        }
        monitor.start(queue: queue)
    }
}
