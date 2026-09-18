import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var resetCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var isCodeSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: isCodeSent ? "lock.rotation" : "key.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)

            VStack(spacing: 4) {
                Text(isCodeSent ? "Reset Password" : "Forgot Password")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(isCodeSent ? "Enter the code sent to your Gmail" : "Enter your email to receive an OTP code")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if !isCodeSent {
                    customTextField(icon: "envelope.fill", placeholder: "Gmail Address", text: $email)
                } else {
                    customTextField(icon: "number.circle.fill", placeholder: "6-Digit Code", text: $resetCode)
                    customSecureField(icon: "lock.fill", placeholder: "New Password", text: $newPassword)
                    customSecureField(icon: "lock.shield.fill", placeholder: "Confirm Password", text: $confirmPassword)
                }
            }

            if let errorMessage = errorMessage {
                statusBanner(message: errorMessage, isError: true)
            } else if let successMessage = successMessage {
                statusBanner(message: successMessage, isError: false)
            }

            Button {
                if isCodeSent { handleResetPassword() } else { handleSendCode() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(isCodeSent ? "Update Password" : "Send Reset OTP")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(isButtonEnabled ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(isButtonEnabled ? .white : .gray)
                .cornerRadius(12)
            }
            .disabled(!isButtonEnabled || isLoading)

            Button("Back to Login") { dismiss() }
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
    }

    private var isButtonEnabled: Bool {
        if !isCodeSent {
            return !email.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return !resetCode.isEmpty && !newPassword.isEmpty && newPassword == confirmPassword
        }
    }

    private func handleSendCode() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let res = try await APIService.shared.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
                isLoading = false
                successMessage = res.message ?? "OTP code dispatched!"
                withAnimation { isCodeSent = true }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleResetPassword() {
        if newPassword != confirmPassword { errorMessage = "Passwords do not match."; return }
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let res = try await APIService.shared.resetPassword(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    code: resetCode.trimmingCharacters(in: .whitespacesAndNewlines),
                    newPassword: newPassword
                )
                isLoading = false
                successMessage = res.message ?? "Password updated successfully!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
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

    private func statusBanner(message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : .green)
            Text(message).font(.footnote).foregroundColor(isError ? .red : .green)
            Spacer()
        }
        .padding()
        .background((isError ? Color.red : Color.green).opacity(0.12))
        .cornerRadius(12)
    }
}
