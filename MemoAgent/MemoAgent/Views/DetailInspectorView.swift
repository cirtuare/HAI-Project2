// DetailInspectorView.swift
// MemoAgent — Phase 4: Detail Inspector
//
// Mounted inside SwiftUI's native .inspector() panel.
// Single-node view: type badge, date, editable summary, collapsible original text.
// Multi-node view: prompt composer with context chips, intent textarea, generated prompt.
// Mirrors DetailDrawer.tsx in full.

import SwiftUI
import SwiftData

struct DetailInspectorView: View {
    @Environment(GraphViewModel.self) private var vm
    @State private var isOriginalExpanded = false
    @State private var promptCopied = false
    @State private var editedSummary = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if vm.selectedNodes.count == 1 {
                singleNodeView(node: vm.selectedNodes[0])
            } else {
                promptComposerView
            }
        }
        .background(Color(hex: "#0f172a"))  // surface-secondary
        .colorScheme(.dark)  // force dark environment so .primary/.secondary resolve to white-family
        .onChange(of: vm.selectedNodes) { _, nodes in
            // Seed the editable summary when selection changes
            isOriginalExpanded = false
            editedSummary = nodes.first?.summary ?? ""
        }
        .onAppear {
            editedSummary = vm.selectedNodes.first?.summary ?? ""
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Header
    // ─────────────────────────────────────────────

    private var header: some View {
        HStack {
            Text(vm.selectedNodes.count > 1 ? "프롬프트 작성" : "노드 상세 정보")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            // Delete button — only in single-node mode
            if vm.selectedNodes.count == 1, let node = vm.selectedNodes.first {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        vm.deleteNode(id: node.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#f43f5e"))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color(hex: "#f43f5e").opacity(0.12)))
                }
                .buttonStyle(.plain)
                .help("노드 삭제")
            }
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    vm.clearSelection()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.quaternary))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // ─────────────────────────────────────────────
    // MARK: Single Node View
    // ─────────────────────────────────────────────

    private func singleNodeView(node: GraphNode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Type badge + date
                HStack(spacing: 8) {
                    Text(node.type.rawValue.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: node.type.hexColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(hex: node.type.hexColor).opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            Color(hex: node.type.hexColor).opacity(0.3),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(node.date)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)
                }

                // Title
                Text(node.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // AI summary (editable)
                VStack(alignment: .leading, spacing: 6) {
                    Label("AI 요약 (수정 가능)", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#8b5cf6"))

                    TextEditor(text: $editedSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 96)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }

                // Collapsible original text
                originalTextDisclosure(node: node)

                Divider()

                // AI Prompt generation section (single node)
                aiPromptSection(node: node)

                // Connected nodes analysis section
                connectedPromptSection(node: node)
            }
            .padding(16)
        }
    }

    private func originalTextDisclosure(node: GraphNode) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isOriginalExpanded.toggle()
                }
            } label: {
                HStack {
                    Label("원본 보기", systemImage: "doc.text")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isOriginalExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: isOriginalExpanded ? 12 : 12, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
            }
            .buttonStyle(.plain)

            if isOriginalExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text(node.originalText)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Button {
                        // Open original source (placeholder)
                    } label: {
                        Label("원본 출처로 이동", systemImage: "arrow.up.right.square")
                            .font(.system(size: 11))
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .clipShape(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // ─────────────────────────────────────────────
    // MARK: AI Prompt Section (single node)
    // ─────────────────────────────────────────────

    @ViewBuilder
    private func aiPromptSection(node: GraphNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Generate button
            if !vm.isGeneratingAIPrompt && vm.aiGeneratedPrompt.isEmpty && vm.aiPromptError == nil {
                Button {
                    vm.generateAIPrompt(for: node)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                        Text("이 노드 바탕 프롬프트 완성")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "#8b5cf6"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "#8b5cf6").opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color(hex: "#8b5cf6").opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            // Loading indicator
            if vm.isGeneratingAIPrompt {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Color(hex: "#8b5cf6"))
                    Text("AI가 프롬프트를 작성 중...")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(.vertical, 8)
            }

            // Streaming / completed result
            if !vm.aiGeneratedPrompt.isEmpty {
                aiResultBox
            }

            // Error
            if let err = vm.aiPromptError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#f59e0b"))
                    Text(err)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#f59e0b").opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color(hex: "#f59e0b").opacity(0.25), lineWidth: 0.5)
                        )
                )
            }
        }
    }

    @State private var aiPromptCopied = false

    private var aiResultBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI 생성 프롬프트", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8b5cf6"))
                Spacer()
                // Re-generate
                Button {
                    if let node = vm.selectedNodes.first {
                        vm.generateAIPrompt(for: node)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .disabled(vm.isGeneratingAIPrompt)
                // Copy
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(vm.aiGeneratedPrompt, forType: .string)
                    withAnimation { aiPromptCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { aiPromptCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: aiPromptCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(aiPromptCopied ? "복사됨" : "복사")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(aiPromptCopied ? Color.green : Color.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }

            Text(vm.aiGeneratedPrompt)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(hex: "#8b5cf6").opacity(0.4), lineWidth: 1)
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // ─────────────────────────────────────────────
    // MARK: Connected Nodes AI Section
    // ─────────────────────────────────────────────

    @ViewBuilder
    private func connectedPromptSection(node: GraphNode) -> some View {
        let connected = vm.connectedNodes(for: node)
        let hasResult = !vm.aiConnectedPrompt.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            Divider()

            // Section header with connected node chips
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cyan.opacity(0.8))
                    Text("연결 노드 포함 분석")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                    Text("\(connected.count)개 연결")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.cyan.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.cyan.opacity(0.1)))
                }

                // Connected node chips
                if !connected.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(connected) { n in
                            HStack(spacing: 4) {
                                Image(systemName: NodeTypeStyle.style(for: n.type).systemImage)
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color(hex: n.type.hexColor))
                                Text(n.title)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.65))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(hex: n.type.hexColor).opacity(0.1))
                                    .overlay(
                                        Capsule().strokeBorder(
                                            Color(hex: n.type.hexColor).opacity(0.25),
                                            lineWidth: 0.5
                                        )
                                    )
                            )
                        }
                    }
                } else {
                    Text("연결된 노드가 없습니다.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }

            // Generate button
            if !vm.isGeneratingConnectedPrompt && vm.aiConnectedPrompt.isEmpty {
                Button {
                    vm.generateConnectedAIPrompt(for: node)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("연결 노드 포함 AI 분석")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.cyan.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            // Loading
            if vm.isGeneratingConnectedPrompt {
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Color.cyan)
                    Text("연결 노드를 함께 분석 중...")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(.vertical, 6)
            }

            // Result
            if hasResult {
                connectedResultBox(node: node)
            }
        }
    }

    @State private var connectedPromptCopied = false

    private func connectedResultBox(node: GraphNode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("[연결 노드 포함] AI 분석 결과", systemImage: "link.badge.plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.cyan)
                Spacer()
                // Re-generate
                Button {
                    vm.generateConnectedAIPrompt(for: node)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .disabled(vm.isGeneratingConnectedPrompt)
                // Copy
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(vm.aiConnectedPrompt, forType: .string)
                    withAnimation { connectedPromptCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { connectedPromptCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: connectedPromptCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(connectedPromptCopied ? "복사됨" : "복사")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(connectedPromptCopied ? Color.green : Color.white.opacity(0.5))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }

            Text(vm.aiConnectedPrompt)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 1)
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // ─────────────────────────────────────────────
    // MARK: Prompt Composer (multi-node)
    // ─────────────────────────────────────────────

    private var promptComposerView: some View {
        @Bindable var vm = vm
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Selected node chips
                selectedChips

                Divider()

                // Intent input
                VStack(alignment: .leading, spacing: 10) {
                    Text("선택한 정보를 바탕으로 무엇을 할까요?")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $vm.promptIntent)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color(hex: "#8b5cf6").opacity(0.4), lineWidth: 1)
                                )
                        )

                    // Suggestion chips
                    FlowLayout(spacing: 6) {
                        ForEach(["보고서 초안 작성", "공통점 요약", "블로그 글쓰기"], id: \.self) { s in
                            Button { vm.promptIntent = s } label: {
                                Text(s)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(Color.primary.opacity(0.06))
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Generate / generated prompt
                if vm.generatedPrompt.isEmpty {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            vm.generatePrompt()
                        }
                    } label: {
                        Label("프롬프트 완성", systemImage: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(hex: "#7c3aed"))
                                    .shadow(color: Color(hex: "#8b5cf6").opacity(0.3), radius: 8, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    generatedPromptBox
                }
            }
            .padding(16)
        }
    }

    private var selectedChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("선택된 지식 블록:")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("\(vm.selectedNodes.count)개")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.cyan)
            }

            FlowLayout(spacing: 6) {
                ForEach(vm.selectedNodes) { node in
                    HStack(spacing: 6) {
                        Text(node.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 140, alignment: .leading)
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                vm.deselectNode(node.id)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
    }

    private var generatedPromptBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("생성된 프롬프트", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8b5cf6"))
                Spacer()
                // Copy button
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(vm.generatedPrompt, forType: .string)
                    withAnimation { promptCopied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { promptCopied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: promptCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(promptCopied ? "복사됨" : "복사")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(promptCopied ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }

            Text(vm.generatedPrompt)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(hex: "#8b5cf6").opacity(0.45), lineWidth: 1)
                )
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    let container = try! ModelContainer(for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let vm = GraphViewModel(modelContext: container.mainContext)
    vm.selectNode("1")
    return DetailInspectorView()
        .environment(vm)
        .frame(width: 360, height: 700)
}
