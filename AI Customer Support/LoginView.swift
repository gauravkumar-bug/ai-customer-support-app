import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false
    @State private var showRegisterView = false

    var body: some View {
        Group {
            if authManager.isMFARequired {
                MFAVerificationView()
            } else {
                standardLoginContent
            }
        }
    }

    private var standardLoginContent: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                Text("Welcome Back")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Sign in to your account")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                Task { await authManager.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.primary.opacity(0.06))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }

            HStack {
                Rectangle().frame(height: 1).opacity(0.15)
                Text("OR").font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                Rectangle().frame(height: 1).opacity(0.15)
            }

            VStack(spacing: 12) {
                customTextField(icon: "envelope.fill", placeholder: "Email Address", text: $email)
                customSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
            }

            HStack {
                Spacer()
                Button("Forgot Password?") { showForgotPassword = true }
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }

            if let errorMessage = authManager.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage).font(.footnote)
                    Spacer()
                }
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.12))
                .cornerRadius(12)
            }

            Button {
                Task { await authManager.login(email: email, password: password) }
            } label: {
                HStack {
                    if authManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Log In").fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(isFormValid ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(isFormValid ? .white : .gray)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || authManager.isLoading)

            HStack {
                Text("Don't have an account?").foregroundColor(.secondary)
                Button("Register") { showRegisterView = true }
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .font(.subheadline)
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
        .sheet(isPresented: $showForgotPassword) { ForgotPasswordView() }
        .sheet(isPresented: $showRegisterView) { RegisterView() }
    }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func customTextField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 20)
            TextField(placeholder, text: text).foregroundColor(.primary)
        }
        .padding()
        .background(Color.primary.opacity(0.06))
        .cornerRadius(12)
    }

    private func customSecureField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 20)
            SecureField(placeholder, text: text).foregroundColor(.primary)
        }
        .padding()
        .background(Color.primary.opacity(0.06))
        .cornerRadius(12)
    }
}
