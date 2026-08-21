import AuthenticationServices
import SwiftUI

/// Signing in and signing up, natively.
///
/// This was login.html in a web view. Two things made that worth replacing
/// beyond how it looked: a password field in a web view cannot be filled by
/// iOS's own password manager the way a native one can, and every failure came
/// back as a styled div rather than something the app could react to.
struct AuthScreen: View {

    enum Mode { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    @FocusState private var focus: Field?
    private enum Field { case name, email, password }

    @ObservedObject private var auth = AuthService.shared
    @EnvironmentObject private var state: AppState

    private var canSubmit: Bool {
        guard email.contains("@"), password.count >= 6, !isWorking else { return false }
        if mode == .signUp { return !name.trimmingCharacters(in: .whitespaces).isEmpty }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                header

                Picker("", selection: $mode) {
                    Text("Sign in").tag(Mode.signIn)
                    Text("Create account").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in errorMessage = nil }

                fields

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isStaticText)
                }

                submitButton

                if mode == .signIn {
                    // The reset flow stays on the site. It is a one-off that
                    // ends in an emailed code, and it carries the Turnstile
                    // challenge, which has to run on a real web page.
                    Button("Forgot your password?") {
                        state.presentedPage = AppState.PresentedPage(
                            title: "Reset Password",
                            url: AppConfig.url("forgot-password.html")
                        )
                    }
                    .font(.callout)
                }

                separator

                socialButtons
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "house.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.brand)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Theme.brand.opacity(0.12)))

            Text(mode == .signIn ? "Welcome back" : "Create your account")
                .font(.title2.weight(.bold))

            Text(mode == .signIn
                 ? "Sign in to message landlords and save rooms."
                 : "It takes a moment, and the AI negotiator comes with it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var fields: some View {
        VStack(spacing: 12) {
            if mode == .signUp {
                field("Full name", text: $name, field: .name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .onSubmit { focus = .email }
            }

            field("Email", text: $email, field: .email)
                // .username, not .emailAddress: it is what iOS files a saved
                // password under, so the keyboard offers the right account.
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .onSubmit { focus = .password }

            SecureField("Password", text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit { if canSubmit { submit() } }
        }
    }

    private func field(_ title: String, text: Binding<String>, field: Field) -> some View {
        TextField(title, text: text)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            .focused($focus, equals: field)
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isWorking {
                ProgressView().tint(.white).frame(maxWidth: .infinity)
            } else {
                Text(mode == .signIn ? "Sign in" : "Create account")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(canSubmit ? Theme.brand : Color.gray.opacity(0.4))
        )
        .foregroundStyle(.white)
        .disabled(!canSubmit)
    }

    private var separator: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
            Text("or").font(.footnote).foregroundStyle(.secondary)
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
        }
    }

    private var socialButtons: some View {
        VStack(spacing: 12) {
            // Apple first. Guideline 4.8 requires it wherever a third-party
            // sign-in is offered, and putting it second reads as the
            // afterthought that rule exists to prevent.
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { _ in
                // Handled through AppleAuthService so the token reaches the
                // same endpoint the website posts to, rather than two code
                // paths that can drift.
                startApple()
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .allowsHitTesting(!isWorking)

            Button(action: startGoogle) {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                    Text("Continue with Google").fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
            }
            .foregroundStyle(.primary)
            .disabled(isWorking)
        }
    }

    // MARK: - Actions

    private func submit() {
        focus = nil
        run {
            if mode == .signIn {
                try await auth.signIn(email: email.trimmed, password: password)
            } else {
                try await auth.register(name: name.trimmed, email: email.trimmed, password: password)
            }
        }
    }

    private func startApple() {
        run {
            let credential = try await AppleAuthService.shared.signIn(
                presentingFrom: UIApplication.shared.firstKeyWindow
            )
            try await auth.signInWithApple(
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode,
                firstName: credential.firstName,
                lastName: credential.lastName
            )
        }
    }

    private func startGoogle() {
        run {
            let result = try await GoogleAuthService.shared.signIn(
                presentingFrom: UIApplication.shared.firstKeyWindow
            )
            try await auth.signInWithGoogle(code: result.code, redirectURI: result.redirectURI)
        }
    }

    /// One place for the spinner, the haptic and the error, so no path can
    /// leave the button spinning forever.
    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        errorMessage = nil

        Task {
            do {
                try await work()
                Haptics.notify(.success)
            } catch is CancellationError {
                // Backing out of a sign-in sheet is not a failure.
            } catch AppleAuthService.AuthError.cancelled {
            } catch GoogleAuthService.AuthError.cancelled {
            } catch {
                errorMessage = error.localizedDescription
                Haptics.notify(.error)
            }
            isWorking = false
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension UIApplication {
    /// The window to hang a system sheet on, without the deprecated
    /// `UIApplication.shared.windows`.
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
