import SwiftUI

/// Pre-use disclosure for the AI Negotiator.
///
/// Required because messages, listing details and budget information are sent
/// to OpenAI's API for processing. Apple and most privacy regulators expect
/// this disclosure *before* the first network call, not buried in settings.
struct AIDataDisclosureView: View {
    let listingTitle: String?
    let onContinue: () -> Void
    let onCancel: () -> Void
    
    @AppStorage("aiNegotiatorDisclosureAccepted") private var disclosureAccepted = false
    @State private var isChecked = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    
                    GroupBox("What happens to your data") {
                        VStack(alignment: .leading, spacing: 12) {
                            bullet("Your messages are sent to OpenAI to generate replies.")
                            bullet("Listing details such as title, price and location are included so the assistant can negotiate accurately.")
                            bullet("Your budget range is shared with OpenAI when you start a negotiation.")
                            bullet("OpenAI may process this data under their privacy policy (openai.com/policies/privacy-policy).")
                        }
                        .font(.subheadline)
                    }
                    
                    GroupBox("How we protect it") {
                        VStack(alignment: .leading, spacing: 12) {
                            bullet("We do not use your chats for advertising.")
                            bullet("Conversations are stored in your RoomFinderAI account so you can review them.")
                            bullet("You can stop using the AI assistant at any time.")
                        }
                        .font(.subheadline)
                    }
                    
                    Toggle(isOn: $isChecked) {
                        Text("I understand and agree that my messages and listing details will be processed by OpenAI.")
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                    
                    buttons
                }
                .padding()
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before you start")
                .font(.title2.bold())
            
            if let title = listingTitle, !title.isEmpty {
                Text("Negotiating: \(title)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("This feature uses artificial intelligence provided by OpenAI. To help you negotiate, some information is sent to OpenAI's servers.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
    }
    
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "smallcircle.fill.circle")
                .font(.caption)
                .foregroundColor(.brandPrimary)
                .padding(.top, 4)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
    
    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                disclosureAccepted = true
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isChecked ? Color.brandPrimary : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!isChecked)
            
            Button("Cancel", role: .cancel, action: onCancel)
                .font(.subheadline)
            
            Link("Read our Privacy Policy", destination: URL(string: "https://www.roomfinderai.com/privacy-policy")!)
                .font(.caption)
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }
}

extension Color {
    static var brandPrimary: Color {
        Color(red: 0.4, green: 0.2, blue: 0.8)
    }
}

#Preview {
    AIDataDisclosureView(
        listingTitle: "2 Bedroom Apartment",
        onContinue: {},
        onCancel: {}
    )
}
