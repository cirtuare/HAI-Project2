// MultiPersonaChatView.swift
// MemoAgent — Phase 4: Multi-Persona Chat
//
// Step A: persona selection panel (left) — PersonaRouter auto-suggests, user toggles
// Step B: chat input + message history (right) — sends to all selected personas in parallel
// "토론 시작" button triggers DebateOrchestrator manually when ≥2 personas are selected.

import SwiftUI
import SwiftData

struct MultiPersonaChatView: View {
    @Environment(GraphViewModel.self) private var vm
    @Environment(\.modelContext) private var modelContext

    var availableWidth: CGFloat = 780

    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private var isNarrow: Bool { availableWidth < 850 }

    var body: some View {
        Group {
            if isNarrow {
                VStack(spacing: 0) {
                    personaRowHeader
                    Divider()
                    chatPanel
                }
            } else {
                HStack(spacing: 0) {
                    personaPanel
                        .frame(width: 220)
                    Divider()
                    chatPanel
                }
            }
        }
        .frame(minWidth: 620, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
        .background(Color(hex: "#1e293b"))
        .colorScheme(.dark)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 40, y: 12)
    }

    // ─────────────────────────────────────────────
    // MARK: Left — Persona Panel
    // ─────────────────────────────────────────────

    // 좁은 레이아웃: 페르소나 칩을 상단 가로 행으로 표시
    private var personaRowHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.cyan)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(vm.personas, id: \.id) { persona in
                        if let pType = persona.personaType {
                            personaChip(persona: persona, personaType: pType)
                        }
                    }
                    if vm.chatSelectedPersonaTypes.count >= 2 {
                        Button {
                            triggerDebate()
                        } label: {
                            Text("토론")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.orange))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 0)

            Button { vm.closeChat() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "#0f172a").opacity(0.6))
    }

    private func personaChip(persona: PersonaRecord, personaType: PersonaType) -> some View {
        let isSelected = vm.chatSelectedPersonaTypes.contains(personaType)
        let accent = Color(hex: personaType.accentHex)
        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                if isSelected { vm.chatSelectedPersonaTypes.remove(personaType) }
                else { vm.chatSelectedPersonaTypes.insert(personaType) }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: personaType.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? accent : Color.white.opacity(0.4))
                Text(personaType.localizedName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.5))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? accent.opacity(0.15) : Color.white.opacity(0.06))
                    .overlay(Capsule().strokeBorder(isSelected ? accent.opacity(0.4) : Color.clear, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var personaPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.cyan)
                Text("참여 페르소나")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer()
                Button { vm.closeChat() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.15)

            if vm.personas.isEmpty {
                emptyPersonaState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(vm.personas, id: \.id) { persona in
                            if let pType = persona.personaType {
                                personaToggleCard(persona: persona, personaType: pType)
                            }
                        }
                    }
                    .padding(12)
                }
            }

            Spacer()

            // Debate trigger (only when ≥2 selected)
            if vm.chatSelectedPersonaTypes.count >= 2 {
                debateButton
                    .padding(12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(Color(hex: "#0f172a").opacity(0.6))
        .animation(.spring(response: 0.3, dampingFraction: 0.8),
                   value: vm.chatSelectedPersonaTypes.count)
    }

    private func personaToggleCard(persona: PersonaRecord, personaType: PersonaType) -> some View {
        let isSelected = vm.chatSelectedPersonaTypes.contains(personaType)
        let isSuggested = vm.suggestedPersonas.contains(personaType)
        let accent = Color(hex: personaType.accentHex)

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                if isSelected {
                    vm.chatSelectedPersonaTypes.remove(personaType)
                } else {
                    vm.chatSelectedPersonaTypes.insert(personaType)
                }
            }
        } label: {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: personaType.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? accent : Color.white.opacity(0.4))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? accent.opacity(0.18) : Color.white.opacity(0.05))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(personaType.localizedName)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.55))

                        // AI suggested badge
                        if isSuggested {
                            Text("추천")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(accent.opacity(0.15)))
                        }
                    }
                }

                Spacer(minLength: 0)

                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? accent : Color.white.opacity(0.2))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var emptyPersonaState: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.2))
            Text("페르소나를 먼저\n만들어주세요")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var debateButton: some View {
        Button {
            triggerDebate()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 11))
                Text("토론 시작")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#f97316"), Color(hex: "#f59e0b")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(hex: "#f97316").opacity(0.3), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
        .help("선택한 페르소나 간 AI 멀티 에이전트 토론을 시작합니다")
    }

    // ─────────────────────────────────────────────
    // MARK: Right — Chat Panel
    // ─────────────────────────────────────────────

    private var chatPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("고민을 던져보세요")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Spacer()
                if vm.chatSelectedPersonaTypes.isEmpty {
                    Text("페르소나를 선택하세요")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.3))
                } else {
                    Text("\(vm.chatSelectedPersonaTypes.count)개 참여 중")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.cyan.opacity(0.8))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.15)

            // Messages
            messagesArea

            Divider().opacity(0.15)

            // Input bar
            inputBar
        }
    }

    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.chatMessages.isEmpty && !vm.isChatLoading {
                        emptyChatPlaceholder
                            .padding(.top, 60)
                    }

                    ForEach(vm.chatMessages, id: \.id) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    if vm.isChatLoading {
                        loadingBubbles
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: vm.chatMessages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(vm.chatMessages.last?.id)
                }
            }
            .onChange(of: vm.isChatLoading) { _, isLoading in
                if isLoading {
                    withAnimation { proxy.scrollTo("loading") }
                }
            }
        }
    }

    private var emptyChatPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.12))
            Text("여러 관점에서 고민을 분석해드립니다")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
    }

    private var loadingBubbles: some View {
        HStack(spacing: 8) {
            ForEach(Array(vm.chatSelectedPersonaTypes), id: \.rawValue) { pType in
                HStack(spacing: 5) {
                    TypingIndicator()
                    Text(pType.localizedName)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: pType.accentHex).opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(hex: pType.accentHex).opacity(0.1))
                )
            }
            Spacer()
        }
        .id("loading")
    }

    private var inputBar: some View {
        @Bindable var vm = vm
        return HStack(spacing: 10) {
            TextField("고민이나 질문을 입력하세요...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isInputFocused
                                              ? Color.cyan.opacity(0.4)
                                              : Color.white.opacity(0.1),
                                              lineWidth: 1)
                        )
                )
                .animation(.easeInOut(duration: 0.15), value: isInputFocused)

            sendButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var sendButton: some View {
        let canSend = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !vm.chatSelectedPersonaTypes.isEmpty
            && !vm.isChatLoading

        return Button { sendMessage() } label: {
            Image(systemName: vm.isChatLoading ? "ellipsis" : "arrow.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(canSend ? .white : Color.white.opacity(0.3))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(canSend ? Color.cyan : Color.white.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .keyboardShortcut(.return, modifiers: .command)
    }

    // ─────────────────────────────────────────────
    // MARK: Actions
    // ─────────────────────────────────────────────

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !vm.chatSelectedPersonaTypes.isEmpty else { return }

        if vm.activeChatSession == nil {
            // First message: use PersonaRouter to refine suggestions
            Task {
                let routed = await PersonaRouter.shared.route(
                    query: text,
                    availablePersonas: vm.personas
                )
                await MainActor.run {
                    // Merge router suggestions with user's manual selection
                    for p in routed { vm.chatSelectedPersonaTypes.insert(p) }
                    vm.startChatSession(query: text)
                    inputText = ""
                }
            }
        } else {
            vm.sendChatMessage(text)
            inputText = ""
        }
    }

    private func triggerDebate() {
        guard vm.chatSelectedPersonaTypes.count >= 2 else { return }
        let personaTypes = Array(vm.chatSelectedPersonaTypes)
        let query = vm.chatMessages.last(where: { $0.role == ChatRole.user })?.content
            ?? "선택된 페르소나 간 교차 분석"
        vm.closeChat()
        vm.triggerManualDebate(personaTypes: personaTypes, query: query)
    }
}

// MARK: - ChatBubble

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.role == ChatRole.user {
            userBubble
        } else {
            personaBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer(minLength: 40)
            Text(message.content)
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.cyan.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 0.5)
                        )
                )
                .textSelection(.enabled)
        }
    }

    private var personaBubble: some View {
        let pType = message.personaType
        let accent = Color(hex: pType?.accentHex ?? "#64748b")

        return HStack(alignment: .top, spacing: 8) {
            // Persona icon
            Image(systemName: pType?.icon ?? "person.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(accent.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(pType?.localizedName ?? "페르소나")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)

                Text(message.content)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accent.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(accent.opacity(0.2), lineWidth: 0.5)
                            )
                    )
                    .textSelection(.enabled)
            }

            Spacer(minLength: 40)
        }
    }
}

// MARK: - TypingIndicator

private struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(phase == i ? 0.7 : 0.2))
                    .frame(width: 4, height: 4)
                    .scaleEffect(phase == i ? 1.2 : 0.8)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                phase = (phase + 1) % 3
            }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = (phase + 1) % 3
                }
            }
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
    // Add sample personas
    let p1 = PersonaRecord.make(from: .health, isActive: true)
    let p2 = PersonaRecord.make(from: .finance)
    container.mainContext.insert(p1)
    container.mainContext.insert(p2)
    vm.personas = [p1, p2]
    vm.chatSelectedPersonaTypes = [.health]
    vm.suggestedPersonas = [.health]

    return MultiPersonaChatView()
        .environment(vm)
        .modelContainer(container)
}
