import UIKit

@MainActor
enum ShareService {

    /// Native share sheet for the page you are looking at. Sharing a room with
    /// a friend is the single most common thing people do on a rentals site,
    /// and inside a web view there is otherwise no way to do it at all — the
    /// address bar that would normally carry the URL is gone.
    static func present(url: URL, title: String?, from presenter: UIViewController) {
        var items: [Any] = [url]
        if let title, !title.isEmpty { items.insert(title, at: 0) }

        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // iPad presents this as a popover and crashes without an anchor.
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = presenter.view
            pop.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                    y: presenter.view.bounds.maxY - 60,
                                    width: 0, height: 0)
            pop.permittedArrowDirections = []
        }

        Haptics.impact(.light)
        presenter.present(sheet, animated: true)
    }
}
