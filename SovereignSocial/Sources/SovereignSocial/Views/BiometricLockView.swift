import SwiftUI

public struct BiometricLockView: View {
    @EnvironmentObject var auth: BiometricAuthManager

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "faceid")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
                .padding()

            Text("Sovereign Enclave Locked")
                .font(.title2).bold()

            Text("Authenticate with Face ID to decrypt your on-device credentials and local strategies.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button(action: {
                Task {
                    _ = await auth.authenticate()
                }
            }) {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
        .padding()
    }
}
