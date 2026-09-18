import SwiftUI

struct MFAVerificationView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var code = ""

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: "shield.checkmark.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)

            VStack(spacing: 6) {
                Text("2-Step Verification")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Enter the verification code sent to your email or authenticator app.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Image(systemName: "number.circle.fill")
                    .foregroundColor(.blue)
                    .frame(width: 20)

                TextField("6-Digit Code", text: $code)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color.primary.opacity(0.06))
            .cornerRadius(12)

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
                    await authManager.verifyMFA(code: code)
                }
            } label: {
                HStack {
                    if authManager.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Verify Code")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(!code.isEmpty ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(!code.isEmpty ? .white : .gray)
                .cornerRadius(12)
            }
            .disabled(code.isEmpty || authManager.isLoading)

            Button("Back to Login") {
                authManager.cancelMFA()
            }
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
}
