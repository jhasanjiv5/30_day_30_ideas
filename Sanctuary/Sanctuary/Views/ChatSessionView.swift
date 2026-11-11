//
//  ChatSessionView.swift
//  Sanctuary
//
//  Turn-Based Rogerian Reflection Interface
//

import SwiftUI
import SwiftData

struct ChatSessionView: View {
    @Bindable var viewModel: TherapySessionViewModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top Turn Progress Bar
            HStack {
                Text("Turn \(min(viewModel.userTurnCount + 1, 4)) of 4")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Wrap Up Early") {
                    Task {
                        await viewModel.wrapUpSession()
                    }
                }
                .font(.caption)
                .foregroundStyle(.indigo)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            Divider()

            // Chat Messages ScrollView
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if let messages = viewModel.currentSession?.messages {
                            ForEach(messages) { msg in
                                MessageBubbleView(message: msg)
                                    .id(msg.id)
                            }
                        }

                        if viewModel.isGenerating && !viewModel.streamingResponse.isEmpty {
                            MessageBubbleView(
                                message: ChatMessage(
                                    sender: "therapist",
                                    content: viewModel.streamingResponse
                                )
                            )
                            .opacity(0.9)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.streamingResponse) { _, _ in
                    if let lastID = viewModel.currentSession?.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Bottom Text Field Input Bar
            HStack(spacing: 10) {
                TextField("What felt prominent today?", text: $viewModel.userInput, axis: .vertical)
                    .focused($isFieldFocused)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .lineLimit(1...4)

                Button {
                    Task {
                        await viewModel.sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.indigo)
                }
                .disabled(viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationTitle("Evening Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.sessionCompleted) {
            if let session = viewModel.currentSession {
                SessionSummarySheet(session: session)
            }
        }
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.isUser ? "You" : "Therapist")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                Text(message.content)
                    .font(message.isUser ? .body : .system(.body, design: .serif))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Color.indigo : Color(.secondarySystemBackground))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }

            if !message.isUser {
                Spacer()
            }
        }
    }
}
