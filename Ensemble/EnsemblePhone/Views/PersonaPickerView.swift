import EnsembleCore
import SwiftUI

struct PersonaPickerView: View {
    @Bindable var model: PhoneAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose Your Profile")
                        .font(.largeTitle.bold())
                    Text("Your watch history stays on this iPhone. Only a normalized genre/mood vector and age constraint flag are shared with Apple TV.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ForEach(model.personas) { persona in
                        Button {
                            model.selectPersona(persona)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: persona.avatarSymbol)
                                    .font(.system(size: 32))
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(persona.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(persona.roleLabel)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(persona.watchHistory.count) local titles · \(persona.isChild ? "Child filter (G/PG)" : "Unrestricted")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Ensemble")
    }
}
