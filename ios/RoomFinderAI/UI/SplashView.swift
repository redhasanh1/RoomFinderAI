import SwiftUI

/// Covers the first page load.
///
/// It continues the brand gradient from the launch screen, so the handover from
/// the system launch image is seamless, and it hides the one moment a web view
/// always looks bad: the blank white frame before the first paint.
struct SplashView: View {

    @State private var appeared = false

    var body: some View {
        ZStack {
            Theme.gradient.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "house.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                    .scaleEffect(appeared ? 1 : 0.86)
                    .opacity(appeared ? 1 : 0)

                Text("RoomFinderAI")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .opacity(appeared ? 1 : 0)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white.opacity(0.9))
                    .padding(.top, 8)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { appeared = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading RoomFinderAI")
    }
}

#Preview { SplashView() }
