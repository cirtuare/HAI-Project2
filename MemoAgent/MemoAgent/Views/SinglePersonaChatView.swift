// SinglePersonaChatView.swift
// MemoAgent — Phase 4: 1:1 Persona Chat
//
// Full-height conversation with a single persona.
// Entered from DebateResultPanel ("○○ 페르소나와 계속 대화 →") or LeftSidebarView persona row.

import SwiftUI
import SwiftData

struct SinglePersonaChatView: View {
    @Environment(GraphViewModel.self) private var vm
    @Environment(\.modelContext) private var modelContext

    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private var personaType: PersonaType? { vm.singleChatPersonaType }
    private var messages: [ChatMessage] { vm.singleChatMessages }
    private var isLoading: Bool { vm.isSingleChatLoading }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            messageList
            Divider().background(Color.white.opacity(0.08))
            inputBar
        }
        .frame(minWidth: 460, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
        .background(Color(hex: "#1e293b"))
        .colorScheme(.dark)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 40, y: 12)
        .onAppear { isInputFocused = true }
    }

    // ─────────────────────────────────────────────
    // MARK: Header
    // ─────────────────────────────────────────────

    private var header: some View {
        HStack(spacing: 10) {
            if let type = personaType {
                // Persona icon badge
                ZStack {
                    Circle()
                        .fill(Color(hex: type.accentHex).opacity(0.2))
                        .frame(width: 32, height: 32)
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: type.accentHex))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.localizedName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text("1:1 전문가 채팅")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            } else {
                Text("페르소나 채팅")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            Spacer()

            // Multi-chat 전환 버튼
            Button {
                vm.closeSingleChat()
                vm.openChat()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 11))
                    Text("멀티 채팅")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.cyan.opacity(0.1)))
                .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.3), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            Button { vm.closeSingleChat() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // ─────────────────────────────────────────────
    // MARK: Message List
    // ─────────────────────────────────────────────

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyState
                    }
                    ForEach(messages) { message in
                        SingleChatBubble(message: message, personaType: personaType)
                            .id(message.id)
                    }
                    if isLoading {
                        SingleTypingIndicator(personaType: personaType)
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    } else if isLoading {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
            .onChange(of: isLoading) {
                if isLoading {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if let type = personaType {
                Image(systemName: type.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(Color(hex: type.accentHex).opacity(0.6))
                Text("\(type.localizedName) 전문가에게 질문해보세요")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // ─────────────────────────────────────────────
    // MARK: Input Bar
    // ─────────────────────────────────────────────

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("메시지를 입력하세요...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.white.opacity(0.2)
                            : (personaType.map { Color(hex: $0.accentHex) } ?? .cyan)
                    )
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }

    // ─────────────────────────────────────────────
    // MARK: Actions
    // ─────────────────────────────────────────────

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }
        inputText = ""
        vm.sendSingleChatMessage(text)
    }
}

// MARK: - SingleChatBubble

private struct SingleChatBubble: View {
    let message: ChatMessage
    let personaType: PersonaType?

    private var isUser: Bool { message.role == ChatRole.user }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
                bubbleContent
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.cyan.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.cyan.opacity(0.3), lineWidth: 0.5)
                            )
                    )
            } else {
                if let type = personaType {
                    ZStack {
                        Circle()
                            .fill(Color(hex: type.accentHex).opacity(0.15))
                            .frame(width: 26, height: 26)
                        Image(systemName: type.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: type.accentHex))
                    }
                }
                bubbleContent
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        personaType.map { Color(hex: $0.accentHex).opacity(0.25) } ?? Color.clear,
                                        lineWidth: 0.5
                                    )
                            )
                    )
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleContent: some View {
        Text(message.content)
            .font(.system(size: 13))
            .foregroundStyle(isUser ? Color.cyan : Color.white.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - SingleTypingIndicator

private struct SingleTypingIndicator: View {
    let personaType: PersonaType?
    @State private var phase: Int = 0

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let type = personaType {
                ZStack {
                    Circle()
                        .fill(Color(hex: type.accentHex).opacity(0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: type.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: type.accentHex))
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 0.7 : 0.25))
                        .frame(width: 6, height: 6)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            Spacer()
        }
        .onAppear {
            phase = 1
        }
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self,
            DebateRecord.self, ChatSession.self, ChatMessage.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let vm = GraphViewModel(modelContext: container.mainContext)
    vm.singleChatPersonaType = .health
    vm.isSingleChatPresented = true
    return SinglePersonaChatView()
        .environment(vm)
        .modelContainer(container)
}
