import Foundation
import StoreKit

/// Pro, bought through the App Store.
///
/// The plan is sold on the website through Stripe, and guideline 3.1.1 does not
/// allow an app to send someone there to unlock features it will then provide.
/// So the app sells it through Apple instead, and the website keeps its own
/// route — the same account ends up Pro either way.
///
/// StoreKit 2 verifies transactions on the device with Apple's own signature
/// before this ever sees them, so an unverified one is dropped rather than
/// trusted. The server is told separately, and checks the signature itself,
/// because anything the app says about what someone has paid for is a claim
/// rather than a fact.
@MainActor
final class ProSubscription: ObservableObject {

    static let shared = ProSubscription()

    /// The one product. A second tier would be another entry in this list and
    /// a group level in App Store Connect.
    static let productID = "com.roomfinderai.app.pro.monthly"

    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    /// Kept so it can be cancelled, and so a second start does not add a second
    /// listener that would handle every transaction twice.
    private var updates: Task<Void, Never>?

    private init() {}

    func start() {
        guard updates == nil else { return }

        // Started before anything is loaded: a purchase can complete while the
        // app is closed — asked for on another device, or interrupted and
        // finished later — and arrives here when it does.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let transaction = try? Self.verified(update) else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }

        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            // Not surfaced. A shop that will not load is a reason to hide the
            // upgrade button, not to put an error in front of somebody who came
            // to read their messages.
            product = nil
        }
    }

    /// Whether this Apple ID currently owns Pro.
    func refreshEntitlement() async {
        var owned = false

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(entitlement),
                  transaction.productID == Self.productID else { continue }
            // revocationDate is set when Apple refunds or a family member's
            // access is withdrawn; such a transaction is still "current" but is
            // no longer something to honour.
            if transaction.revocationDate == nil { owned = true }
        }

        isPro = owned
        if owned { await tellServer() }
    }

    func purchase() async {
        guard let product else {
            errorMessage = "The upgrade isn't available right now. Try again shortly."
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let result):
                let transaction = try Self.verified(result)
                await transaction.finish()
                await refreshEntitlement()
                Haptics.notify(.success)

            case .userCancelled:
                // Backing out is not a failure and gets no error.
                break

            case .pending:
                // Ask to Buy, or a payment method needing approval. It may
                // complete later, and Transaction.updates will catch it.
                errorMessage = "That purchase needs approval before it can finish."

            @unknown default:
                break
            }
        } catch {
            errorMessage = "The purchase didn't go through. You haven't been charged."
            Haptics.notify(.error)
        }
    }

    /// For a new device, or a reinstall. Apple requires this to be reachable
    /// without a purchase.
    func restore() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        try? await AppStore.sync()
        await refreshEntitlement()

        if !isPro {
            errorMessage = "No previous purchase was found on this Apple ID."
        }
    }

    /// Hands the signed transaction to the server so the website knows too.
    ///
    /// The JWS is passed through untouched: the server verifies Apple's
    /// signature on it rather than believing a flag this app sends.
    private func tellServer() async {
        guard let email = AuthService.shared.profile?.email ?? CurrentUser.shared.email else { return }

        var latest: String?
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Self.productID {
                latest = entitlement.jwsRepresentation
            }
        }
        guard let jws = latest else { return }

        var request = URLRequest(url: AppConfig.url("api/subscription/apple"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "userEmail": email,
            "signedTransaction": jws
        ])
        _ = try? await URLSession.shared.data(for: request)
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            // Apple could not vouch for it, so neither will this.
            throw StoreError.unverified
        }
    }

    enum StoreError: Error { case unverified }
}
