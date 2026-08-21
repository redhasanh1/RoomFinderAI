import SwiftUI

/// Legal help, natively.
///
/// This was the site's Legal Center in a web view: a desktop page with its own
/// header, its own tabs and its own scrolling inside the app's, which is both
/// the thing App Review calls out and the thing that makes an app feel like a
/// bookmark. The work behind it is three API calls; everything else was layout
/// that iOS already provides.
struct LegalScreen: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        LegalQuestionScreen()
                    } label: {
                        row("Ask a question",
                            "Describe your situation and get a plain answer",
                            "bubble.left.and.text.bubble.right.fill")
                    }

                    NavigationLink {
                        LeaseReviewScreen()
                    } label: {
                        row("Review my lease",
                            "Paste it and we'll flag what's unusual",
                            "doc.text.magnifyingglass")
                    }

                    NavigationLink {
                        LegalDocumentScreen()
                    } label: {
                        row("Write a letter",
                            "Notice to vacate, repair request, deposit demand",
                            "square.and.pencil")
                    }
                } header: {
                    Text("Get help")
                } footer: {
                    Text("This is general information, not legal advice. For anything going to court, talk to a lawyer.")
                }

                Section("Know your rights") {
                    ForEach(LegalRight.all) { right in
                        NavigationLink {
                            LegalRightScreen(right: right)
                        } label: {
                            row(right.title, right.summary, right.symbol)
                        }
                    }
                }
            }
            .navigationTitle("Legal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.brand)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }
}

/// One area of tenant law, written out rather than fetched: these do not change
/// week to week, and a rights page that needs a network call is a rights page
/// that fails when you most want it.
struct LegalRight: Identifiable {
    let id: String
    let title: String
    let summary: String
    let symbol: String
    let points: [String]

    static let all: [LegalRight] = [
        .init(id: "deposit", title: "Security deposits",
              summary: "What can be withheld, and how to get it back",
              symbol: "banknote",
              points: [
                "A deposit is your money being held, not the landlord's to spend.",
                "It can usually only be kept for unpaid rent or damage beyond normal wear.",
                "Normal wear is faded paint, worn carpet, small nail holes. It is not damage.",
                "Most places set a deadline to return it after you move out, often 14 to 30 days.",
                "Photograph every room the day you move in and the day you leave.",
                "Ask for an itemised list in writing if any of it is kept."
              ]),
        .init(id: "increase", title: "Rent increases",
              summary: "Notice periods and what counts as too much",
              symbol: "chart.line.uptrend.xyaxis",
              points: [
                "A rent increase almost always needs written notice, commonly 60 to 90 days.",
                "Mid-lease increases are usually not allowed unless the lease itself says so.",
                "Rent-controlled buildings often cap the yearly rise to a set percentage.",
                "An increase used to punish a complaint may count as retaliation.",
                "Keep every notice. The date it was served is often what decides the argument."
              ]),
        .init(id: "eviction", title: "Eviction",
              summary: "What a landlord must do before you have to leave",
              symbol: "exclamationmark.shield",
              points: [
                "A landlord cannot evict by changing the locks, removing doors or cutting utilities.",
                "Eviction goes through a court or tribunal, and you get a chance to respond.",
                "You must be served written notice with a reason and a deadline.",
                "Do not ignore court papers. Missing the date usually loses the case by default.",
                "Paying overdue rent within the notice period often stops the process."
              ]),
        .init(id: "repairs", title: "Repairs and maintenance",
              summary: "What the landlord has to fix, and how to make them",
              symbol: "wrench.and.screwdriver",
              points: [
                "Somewhere fit to live in is a legal minimum, not a favour.",
                "Heat, water, working plumbing and a sound structure are the landlord's job.",
                "Ask in writing. A text or email is evidence; a phone call is not.",
                "Give a reasonable deadline, and say what you will do if it passes.",
                "Some places let you repair and deduct, or withhold rent. Check before you do either."
              ]),
        .init(id: "privacy", title: "Privacy and entry",
              summary: "When a landlord can come in",
              symbol: "lock.shield",
              points: [
                "Your home is yours while you rent it, including from the landlord.",
                "Entry usually needs advance written notice, commonly 24 hours.",
                "Notice is for a reasonable hour and a stated reason: repairs, inspection, a viewing.",
                "Genuine emergencies, like a burst pipe or a fire, need no notice.",
                "Repeated entry without notice can amount to harassment."
              ]),
        .init(id: "discrimination", title: "Discrimination",
              summary: "What a landlord cannot refuse you for",
              symbol: "person.2.slash",
              points: [
                "Refusing someone over race, religion, sex, disability, family status or origin is illegal in most places.",
                "It also covers the advert, the viewing, the terms offered and the eviction.",
                "A disabled tenant can usually ask for reasonable adjustments, like a support animal.",
                "Save the listing, the messages and the dates. Patterns are what prove a case.",
                "Housing authorities take complaints directly, and it costs nothing to file one."
              ])
    ]
}

struct LegalRightScreen: View {
    let right: LegalRight

    var body: some View {
        List {
            Section {
                ForEach(Array(right.points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.brand)
                            .padding(.top, 3)
                        Text(point)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("Rules differ by province, state and city. Treat this as a starting point and check what applies where you live.")
            }
        }
        .navigationTitle(right.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
