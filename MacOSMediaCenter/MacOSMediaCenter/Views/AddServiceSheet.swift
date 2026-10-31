import SwiftUI

struct AddServiceSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onAdd: (String, String, String) throws -> Void

    @State private var name = ""
    @State private var website = ""
    @State private var upNextTitle = ""
    @State private var errorMessage: String?
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add a Service")
                .font(.title2.weight(.semibold))

            Text("Add a streaming service or any website. It will appear as a tile in your dashboard.")
                .foregroundStyle(.secondary)

            TextField("Service name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFieldFocused)
                .accessibilityLabel("Service name")

            TextField("Website (for example, https://example.com)", text: $website)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Website address")

            Text("A service vibe and recommendations will be generated automatically on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextField("Up Next title for banner artwork (optional)", text: $upNextTitle)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Up Next title")

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add Service") {
                    do {
                        try onAdd(name, website, upNextTitle)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            nameFieldFocused = true
        }
    }
}
