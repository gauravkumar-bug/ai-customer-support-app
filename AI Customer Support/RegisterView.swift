import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        VStack(spacing: 20) {

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 70, height: 70)

                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }

                Text("Create Account")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Register to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                Task {
                    await authManager.signInWithGoogle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)

                    Text("Sign up with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
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
                customTextField(icon: "person.fill", placeholder: "Full Name", text: $name)
                customTextField(icon: "envelope.fill", placeholder: "Email Address", text: $email)
                customSecureField(icon: "lock.fill", placeholder: "Password", text: $password)
                customSecureField(icon: "lock.shield.fill", placeholder: "Confirm Password", text: $confirmPassword)
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
                Task {
                    await authManager.register(name: name, email: email, password: password)
                }
            } label: {
                HStack {
                    if authManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Account")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isFormValid ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(isFormValid ? .white : .gray)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || authManager.isLoading)

            HStack {
                Text("Already have an account?")
                    .foregroundColor(.secondary)

                Button("Login") {
                    dismiss()
                }
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
    }

    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && password == confirmPassword
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
