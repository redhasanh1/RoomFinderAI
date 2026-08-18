import SwiftUI

/// A listing's photos, full screen.
///
/// The detail screen fits each photo inside a 4:3 stage so the whole room is
/// visible at a glance, which necessarily makes it small. This is the other
/// half of that trade: tap a photo and see it as large as the screen allows,
/// pinch or double-tap to go closer, and swipe between the rest.
struct PhotoViewer: View {

    let urls: [URL]
    @Binding var index: Int

    @Environment(\.dismiss) private var dismiss

    /// Zoom is per-photo and resets on the way out, so arriving at the next
    /// photo half-magnified from the last one cannot happen.
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private let maxScale: CGFloat = 5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { position, url in
                    photo(url).tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
            // Paging has to stop while zoomed in, or a drag across a magnified
            // photo flicks to the next one instead of panning this one.
            .disabled(scale > 1)

            controls
        }
        .statusBarHidden()
        .onChange(of: index) { _, _ in resetZoom() }
    }

    private func photo(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)   // never crop or distort
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnification)
                    .simultaneousGesture(pan)
                    .onTapGesture(count: 2) { toggleZoom() }
            case .empty:
                ProgressView().tint(.white)
            default:
                Image(systemName: "photo")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button {
                    Haptics.impact(.light)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Close")

                Spacer()

                if urls.count > 1 {
                    Text("\(index + 1) of \(urls.count)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            Spacer()
        }
    }

    // MARK: - Zoom

    private var magnification: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(1, committedScale * value.magnification), maxScale)
            }
            .onEnded { _ in
                committedScale = scale
                if scale <= 1 { resetZoom() }
            }
    }

    /// Only active while zoomed, so it never competes with paging.
    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1 else { return }
                committedOffset = offset
            }
    }

    private func toggleZoom() {
        Haptics.impact(.light)
        withAnimation(.easeOut(duration: 0.22)) {
            if scale > 1 {
                resetZoom()
            } else {
                scale = 2.5
                committedScale = 2.5
            }
        }
    }

    private func resetZoom() {
        scale = 1
        committedScale = 1
        offset = .zero
        committedOffset = .zero
    }
}
