import UIKit

/// Thin wrapper so taps feel like native controls.
///
/// The generators are kept alive rather than created per tap: allocating one at
/// the moment of the tap adds the Taptic Engine warm-up to the latency, which
/// is exactly the delay that makes hybrid apps feel cheap.
@MainActor
enum Haptics {

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        light.prepare()
        selection.prepare()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .heavy:  heavy.impactOccurred()
        case .medium: medium.impactOccurred()
        default:      light.impactOccurred()
        }
    }

    static func select() {
        selection.selectionChanged()
        selection.prepare()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notification.notificationOccurred(type)
    }
}
