import SwiftUI

struct TileGridView: View {
    let channels: [ChannelItem]
    @Binding var focusedChannel: ChannelItem?
    let namespace: Namespace.ID
    let onSelect: (ChannelItem) -> Void
    let onAddCustom: () -> Void
    let onRemove: (ChannelItem) throws -> Void

    @State private var channelToRemove: ChannelItem?
    @State private var removalError: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 18) {
                ForEach(channels) { channel in
                    ChannelTileView(
                        channel: channel,
                        isFocused: focusedChannel?.id == channel.id,
                        namespace: namespace,
                        onSelect: {
                            focusedChannel = channel
                            onSelect(channel)
                        },
                        onRemove: channel.id.hasPrefix("custom-")
                            ? { channelToRemove = channel }
                            : nil
                    )
                    .onHover { isHovering in
                        if isHovering {
                            focusedChannel = channel
                        }
                    }
                }

                Button {
                    onAddCustom()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        VStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                            Text("Add")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(width: 190, height: 145)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 38)
        }
        .confirmationDialog(
            "Remove \(channelToRemove?.name ?? "service")?",
            isPresented: Binding(
                get: { channelToRemove != nil },
                set: { if !$0 { channelToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Service", role: .destructive) {
                guard let channel = channelToRemove else { return }
                do {
                    try onRemove(channel)
                } catch {
                    removalError = error.localizedDescription
                }
                channelToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                channelToRemove = nil
            }
        } message: {
            Text("This removes \(channelToRemove?.name ?? "this service") and its saved banner artwork from this dashboard.")
        }
        .alert(
            "Unable to Remove Service",
            isPresented: Binding(
                get: { removalError != nil },
                set: { if !$0 { removalError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                removalError = nil
            }
        } message: {
            Text(removalError ?? "")
        }
    }
}
