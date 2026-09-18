import SwiftUI
import Combine

#if os(macOS)
import AppKit
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
final class AuthManager: ObservableObject {

    static let shared = AuthManager()

    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MFA Flow Properties
    @Published var isMFARequired: Bool = false
    private var pendingMFAToken: String?
    private var pendingMFAEmail: String?

    private init() {
        self.isAuthenticated = KeychainManager.shared.hasToken
    }

    // MARK: - Login
    func login(email: String, password: String) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
         
        guard !cleanEmail.isEmpty else { errorMessage = "Please enter your email."; return }
        guard !password.isEmpty else { errorMessage = "Please enter your password."; return }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await APIService.shared.login(email: cleanEmail, password: password)

            // NOTE: the real backend's /login endpoint never returns
            // mfa_required/mfa_token at all — 2FA there is a separate,
            // manual flow (/api/auth/send-otp + /api/auth/verify-otp)
            // that isn't wired into login. This branch is kept for when
            // that gets connected, but with the current backend it will
            // never trigger.
            if response.mfaRequired == true, let mfaToken = response.mfaToken {
                self.pendingMFAToken = mfaToken
                self.pendingMFAEmail = cleanEmail
                self.isMFARequired = true
                return
            }

            guard let token = response.token ?? response.validToken else {
                errorMessage = response.message ?? "Failed to receive authorization token."
                return
            }

            let saved = KeychainManager.shared.saveToken(token)
            guard saved else {
                errorMessage = "Unable to save login session."
                return
            }

            isAuthenticated = true
        } catch {
            print("🔥 REAL ERROR (Login): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Verify MFA Code
    func verifyMFA(code: String) async {
        guard let email = pendingMFAEmail else {
            errorMessage = "MFA session expired. Please log in again."
            isMFARequired = false
            return
        }

        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCode.isEmpty else {
            errorMessage = "Please enter the verification code."
            return
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            // The real backend's /auth/verify-mfa just confirms the OTP
            // and returns {"status", "message"} — it does NOT issue a
            // fresh access_token. So on success we don't have a token to
            // save here; the token from the original login() call (if
            // any) is what's actually used. This flow is currently
            // disconnected from login on the backend, so treat this as
            // "OTP confirmed" rather than "now logged in."
            let response = try await APIService.shared.verifyMFA(email: email, otp: cleanCode)

            if let token = response.token ?? response.validToken {
                let saved = KeychainManager.shared.saveToken(token)
                guard saved else {
                    errorMessage = "Unable to save login session."
                    return
                }
            }

            self.pendingMFAToken = nil
            self.pendingMFAEmail = nil
            self.isMFARequired = false
            self.isAuthenticated = true
        } catch {
            print("🔥 REAL ERROR (MFA): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Register
    func register(name: String, email: String, password: String) async {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanName.isEmpty else { errorMessage = "Please enter your name."; return }
        guard !cleanEmail.isEmpty else { errorMessage = "Please enter your email."; return }
        guard !password.isEmpty else { errorMessage = "Please enter your password."; return }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let registerResponse = try await APIService.shared.register(name: cleanName, email: cleanEmail, password: password)

            if let token = registerResponse.token ?? registerResponse.validToken {
                let saved = KeychainManager.shared.saveToken(token)
                guard saved else {
                    errorMessage = "Session could not be saved."
                    return
                }
                isAuthenticated = true
            } else {
                await login(email: cleanEmail, password: password)
            }
        } catch {
            print("🔥 REAL ERROR (Register): \(error)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Google Sign-In
    func signInWithGoogle() async {
        #if canImport(GoogleSignIn)

        self.isLoading = true
        self.errorMessage = nil

        do {
            var email: String?
            var name: String?

            #if os(iOS)
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                self.isLoading = false
                self.errorMessage = "Unable to launch Google Sign-In window."
                return
            }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            email = result.user.profile?.email
            name = result.user.profile?.name

            #elseif os(macOS)
            guard let presentingWindow = NSApplication.shared.windows.first else {
                self.isLoading = false
                self.errorMessage = "Unable to launch Google Sign-In window."
                return
            }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingWindow)
            email = result.user.profile?.email
            name = result.user.profile?.name

            #else
            self.isLoading = false
            self.errorMessage = "Google Sign-In is not supported on this platform."
            return
            #endif

            guard let email = email else {
                self.isLoading = false
                self.errorMessage = "Google did not return an email address."
                return
            }

            // NOTE: this backend's /api/auth/google trusts whatever
            // email/name the client sends — it does not verify the
            // Google ID token server-side. That's a real gap on the
            // backend's side (anyone could call that endpoint directly
            // with any email and get a session), but from the app's
            // perspective this is what the server currently expects.
            let response = try await APIService.shared.googleSignIn(
                email: email,
                name: name ?? ""
            )

            guard let token = response.token ?? response.validToken else {
                self.isLoading = false
                self.errorMessage = response.message ?? "Google sign-in failed to return a session token."
                return
            }

            let saved = KeychainManager.shared.saveToken(token)
            guard saved else {
                self.isLoading = false
                self.errorMessage = "Unable to save login session."
                return
            }

            self.isLoading = false
            self.isAuthenticated = true
        } catch {
            print("🔥 REAL ERROR (Google Sign-In): \(error)")
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
        #else
        self.errorMessage = "Google Sign-In requires the GoogleSignIn package to be added to this project."
        #endif
    }

    // MARK: - Logout
    func logout() {
        KeychainManager.shared.clearAll()
        isMFARequired = false
        pendingMFAToken = nil
        isAuthenticated = false
        errorMessage = nil
    }

    func cancelMFA() {
        isMFARequired = false
        pendingMFAToken = nil
        pendingMFAEmail = nil
        errorMessage = nil
    }

    func token() -> String? {
        return KeychainManager.shared.getToken()
    }
}
