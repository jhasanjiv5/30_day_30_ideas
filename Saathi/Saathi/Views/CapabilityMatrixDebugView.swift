import SwiftUI
import UIKit
import SaathiCore

struct CapabilityMatrixDebugView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var coordinator: SessionCoordinator
    @State private var markdownOutput: String = ""
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Runtime Multilingual Capability Matrix")
                        .font(.headline)
                    Text("Run this screen on a physical iPhone with Apple Intelligence to export the exact README capability table.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        UIPasteboard.general.string = markdownOutput
                        copied = true
                    } label: {
                        Label(copied ? "Copied Markdown!" : "Export Markdown to Clipboard", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text(markdownOutput)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("Capability Matrix")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    let caps = await coordinator.evaluateAllLanguageCapabilities()
                    let device = "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
                    markdownOutput = CapabilityMatrixMarkdownExporter.exportMarkdown(
                        capabilities: caps,
                        deviceDescription: device
                    )
                }
            }
        }
    }
}
