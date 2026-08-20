import SwiftUI

/// The people side of the marketplace: subleases and roommates, one tab.
///
/// Both were built and only one was reachable — RoomPal was in neither the tab
/// bar nor the menu, so a finished screen sat in the binary that nobody could
/// open. The bar holds five slots and Post owns the middle one, so the two
/// halves share a slot rather than pushing Messages or Profile off the end.
///
/// The switcher is pills, not a segmented control, because each half already
/// has a segmented control of its own. Two identical grey rows stacked on top
/// of each other would read as one confusing four-way choice; a filled pill row
/// above a segmented row reads as "which section" above "which of these".
struct PeopleScreen: View {

    enum Mode: String, CaseIterable, Identifiable {
        case subleases
        case roommates

        var id: String { rawValue }

        var title: String {
            switch self {
            case .subleases: return "Subleases"
            case .roommates: return "Roommates"
            }
        }

        var symbol: String {
            switch self {
            case .subleases: return "calendar.badge.clock"
            case .roommates: return "person.2.fill"
            }
        }
    }

    @EnvironmentObject private var state: AppState

    /// Kept on the shared state rather than here: the plus in the tab bar sits
    /// outside this view and has to open the form for whichever half you are
    /// actually reading.
    private var mode: Mode { state.peopleShowsRoommates ? .roommates : .subleases }

    var body: some View {
        // Each half keeps its own navigation stack and title, so the large
        // title says which side you are on without the switcher having to.
        switch mode {
        case .subleases:
            SubleaseScreen(header: AnyView(switcher))
        case .roommates:
            RoomPalScreen(header: AnyView(switcher))
        }
    }

    private var switcher: some View {
        HStack(spacing: 8) {
            ForEach(Mode.allCases) { option in
                let selected = option == mode
                Button {
                    guard option != mode else { return }
                    Haptics.select()
                    state.peopleShowsRoommates = (option == .roommates)
                } label: {
                    Label(option.title, systemImage: option.symbol)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            Capsule().fill(selected
                                           ? AnyShapeStyle(Theme.gradient)
                                           : AnyShapeStyle(Color(.secondarySystemBackground)))
                        )
                        .foregroundStyle(selected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}
