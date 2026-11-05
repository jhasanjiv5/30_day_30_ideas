import SwiftUI

public struct VaultView: View {
    @EnvironmentObject var vault: SecureVaultStore
    @EnvironmentObject var auth: BiometricAuthManager

    public var body: some View {
        NavigationStack {
            List(vault.credentials) { cred in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(cred.service).font(.headline)
                        Spacer()
                        Text(cred.category).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(cred.username).font(.subheadline.monospaced())
                    HStack {
                        Text("••••••••••••••••").font(.caption.monospaced())
                        Spacer()
                        if cred.hasTotp {
                            Label("2FA Active", systemImage: "key.fill")
                                .font(.caption2)
                                .foregroundStyle(.indigo)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Encrypted Vault")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { auth.lock() }) {
                        Label("Lock", systemImage: "lock.fill")
                    }
                }
            }
        }
    }
}
