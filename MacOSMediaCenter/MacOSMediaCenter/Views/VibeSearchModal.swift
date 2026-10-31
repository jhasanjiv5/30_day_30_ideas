import SwiftUI

struct VibeSearchModal: View {
    @ObservedObject var engine: CoreMLVibeEngine
    let channels: [ChannelItem]
    @Binding var isPresented: Bool
    let onSelectChannel: (ChannelItem) -> Void

    @State private var prompt: String = ""
    @State private var result: CoreMLVibeEngine.VibeResult?

    init(engine: CoreMLVibeEngine, channels: [ChannelItem], isPresented: Binding<Bool>, onSelectChannel: @escaping (ChannelItem) -> Void) {
        self.engine = engine
        self.channels = channels
        self._isPresented = isPresented
        self.onSelectChannel = onSelectChannel
        self._result = State(initialValue: nil)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 18) {
                HStack {
                    Text("Vibe Search")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }

                TextField("Describe your mood…", text: $prompt)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 460)

                if engine.isProcessing {
                    ProgressView(value: 0.7)
                        .frame(width: 460)
                }

                if let result {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.reason)
                            .foregroundStyle(.white.opacity(0.9))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(result.suggestedTitles, id: \.self) { title in
                                    Text(title)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .frame(width: 460, alignment: .leading)
                }

                HStack(spacing: 12) {
                    Button("Search") {
                        Task {
                            engine.isProcessing = true
                            let vibe = await engine.analyzeVibe(prompt: prompt, availableChannels: channels)
                            result = vibe
                            engine.isProcessing = false

                            if let match = channels.first(where: { $0.id == vibe.channelId }) {
                                onSelectChannel(match)
                                isPresented = false
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(24)
            .frame(width: 540)
            .background(.black.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 24, y: 12)
        }
    }
}
