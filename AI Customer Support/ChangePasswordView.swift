import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var validationMessage: String? {
        if newPassword.isEmpty && confirmPassword.isEmpty { return nil }
        if newPassword.count < 8 { return "New password must be at least 8 characters." }
        if newPassword == currentPassword { return "New password must be different from the current one." }
        if !confirmPassword.isEmpty && newPassword != confirmPassword { return "Passwords do not match." }
        return nil
    }

    private var isButtonEnabled: Bool {
        !currentPassword.isEmpty
            && newPassword.count >= 8
            && newPassword == confirmPassword
            && newPassword != currentPassword
            && successMessage == nil
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 70, height: 70)
                Image(systemName: "key.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)

            VStack(spacing: 4) {
                Text("Change Password")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Enter your current password and choose a new one")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                field(icon: "lock.fill", placeholder: "Current Password", text: $currentPassword)
                field(icon: "lock.rotation", placeholder: "New Password (min 8 characters)", text: $newPassword)
                field(icon: "lock.shield.fill", placeholder: "Confirm New Password", text: $confirmPassword)
            }

            if let errorMessage = errorMessage {
                banner(errorMessage, isError: true)
            } else if let successMessage = successMessage {
                banner(successMessage, isError: false)
            } else if let validationMessage = validationMessage {
                banner(validationMessage, isError: true)
            }

            Button {
                submit()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Update Password").fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(isButtonEnabled ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(isButtonEnabled ? .white : .gray)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(!isButtonEnabled || isLoading)

            Button("Cancel") { dismiss() }
                .font(.subheadline)
                .foregroundColor(.blue)
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: 400)
        .frame(minWidth: 340)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 22)
            SecureField(placeholder, text: text)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(12)
    }

    private func banner(_ message: String, isError: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundColor(isError ? .red : .green)
        .padding(12)
        .frame(maxWidth: .infinity)
        .background((isError ? Color.red : Color.green).opacity(0.12))
        .cornerRadius(12)
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await APIService.shared.changePassword(current: currentPassword, new: newPassword)
                await MainActor.run {
                    isLoading = false
                    successMessage = "Password changed successfully."
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if case APIError.serverError(let msg) = error {
                        errorMessage = msg
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
