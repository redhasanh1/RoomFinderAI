import SwiftUI

/// The screen shown when a page will not load.
///
/// It exists so failure looks like the app handling a problem rather than the
/// app breaking. WebKit's own error page — "Safari cannot open the page" — is
/// the single fastest way to tell a user they are looking at a web view.
struct StatusScreen: View {

    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(Theme.gradient)
                .accessibilityHidden(true)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text(actionTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    StatusScreen(
        symbol: "wifi.slash",
        title: "No connection",
        message: "RoomFinderAI needs the internet to show rooms. Reconnect and try again.",
        actionTitle: "Try Again",
        action: {}
    )
}
