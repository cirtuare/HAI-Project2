// DebateStatusBanner.swift
// MemoAgent V2 — Multi-Agent Debate UI: status indicator + completion notification
//
// DebateStatusBanner  — floating pill at canvas top during active debate
// DebateResultPanel   — slide-in card at bottom-right showing synthesis result

import SwiftUI
import SwiftData

// MARK: - DebateStatusBanner

/// Floating pill displayed while the debate orchestrator is running.
/// Positioned at the top of GraphCanvasView by the parent.
struct DebateStatusBanner: View {
    @Environment(GraphViewModel.self) private var vm
    @State private var spinAngle: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            // Animated tri-dot orb
            orb

            Text(vm.debateStatus ?? "AI 에이전트 분석 중...")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(bannerBackground)
        .shadow(color: Color(hex: "#f97316").opacity(0.3), radius: 16)
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                spinAngle = 360
            }
        }
    }

    // ── Spinning tri-color orb ──

    private var orb: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: "#f97316"), Color(hex: "#f59e0b"), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(spinAngle))
        }
    }

    private var bannerBackground: some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.96))
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(hex: "#f97316").opacity(0.7),
                            Color(hex: "#f59e0b").opacity(0.4),
                            Color(hex: "#f97316").opacity(0.2)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - DebateResultPanel

/// Slide-in card shown at bottom-right of ContentView when a debate completes.
/// Parses the synthesis JSON and presents rootCause + 3 action items.
struct DebateResultPanel: View {
    @Environment(GraphViewModel.self) private var vm
    let onDismiss: () -> Void

    @State private var expandedAgents: Set<Int> = []
    @State private var showFullRaw = false

    private var synthesis: DebateSynthesisDisplay? {
        guard let json = vm.activeDebateResult else { return nil }
        return parseSynthesis(json)
    }

    // Analysis turns from each specialist (role == "analysis")
    private var analysisTurns: [AgentTurn] {
        vm.activeDebateTranscript.filter { $0.role == "analysis" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !analysisTurns.isEmpty {
                        agentPositionsSection
                        Divider().background(Color.white.opacity(0.08)).padding(.vertical, 2)
                    }
                    if let s = synthesis {
                        content(s)
                    } else {
                        rawFallback
                    }
                }
            }
        }
        .frame(width: 380)
        .frame(maxHeight: 620)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#f97316").opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
    }

    // MARK: Agent Positions

    private var agentPositionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("각 에이전트 입장", systemImage: "person.2.wave.2")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: "#f97316"))
                .padding(.horizontal, 14)
                .padding(.top, 12)

            ForEach(Array(analysisTurns.enumerated()), id: \.offset) { index, turn in
                agentPositionCard(turn, index: index)
            }
        }
        .padding(.bottom, 8)
    }

    private func agentPositionCard(_ turn: AgentTurn, index: Int) -> some View {
        let accent = domainAccent(turn.domain)
        let needsTruncation = turn.content.count > 120
        let isExpanded = expandedAgents.contains(index)
        let displayText = (isExpanded || !needsTruncation)
            ? turn.content
            : String(turn.content.prefix(120)) + "…"
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: domainIcon(turn.domain))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Text(domainName(turn.domain))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
                Text("\(Int(turn.confidence * 100))%")
                    .font(.system(size: 9))
                    .foregroundStyle(accent.opacity(0.7))
            }
            Text(displayText)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            if needsTruncation {
                Button {
                    if isExpanded { expandedAgents.remove(index) } else { expandedAgents.insert(index) }
                } label: {
                    Text(isExpanded ? "접기" : "더보기")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(accent.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(accent.opacity(0.2), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 14)
    }

    private func domainAccent(_ domain: String) -> Color {
        switch domain {
        case "health":   return Color(hex: "#1D9E75")
        case "academic": return Color(hex: "#7F77DD")
        case "finance":  return Color(hex: "#EF9F27")
        case "hobby":    return Color(hex: "#D85A30")
        default:         return Color(hex: "#64748b")
        }
    }

    private func domainName(_ domain: String) -> String {
        switch domain {
        case "health":      return "건강"
        case "work":        return "업무"
        case "academic":    return "학업"
        case "finance":     return "금융"
        case "hobby":       return "취미"
        case "synthesizer": return "종합"
        default:            return domain
        }
    }

    private func domainIcon(_ domain: String) -> String {
        switch domain {
        case "health":   return "heart.fill"
        case "work":     return "briefcase.fill"
        case "academic": return "book.fill"
        case "finance":  return "dollarsign.circle.fill"
        case "hobby":    return "star.fill"
        default:         return "circle.fill"
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#f97316"))
            Text("AI 멀티 에이전트 분석 완료")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(5)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Parsed content

    private func content(_ s: DebateSynthesisDisplay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Root cause
            VStack(alignment: .leading, spacing: 4) {
                Label("근본 원인", systemImage: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#f97316"))
                Text(s.rootCause)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().background(Color.white.opacity(0.08))

            // Action items with utility scores
            VStack(alignment: .leading, spacing: 6) {
                Label("실행 계획 (기대 효용 순)", systemImage: "checklist")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#22c55e"))

                ForEach(Array(s.actions.enumerated()), id: \.offset) { i, action in
                    let scoreCount = s.actionScores?.count ?? 0
                    let score: Double? = scoreCount > i ? s.actionScores![i] : nil
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: "#f97316"))
                                .frame(width: 14, height: 14)
                                .background(Circle().fill(Color(hex: "#f97316").opacity(0.15)))
                            Text(action)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                            if let sc = score {
                                Text("\(Int(sc * 100))%")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(utilityColor(sc))
                            }
                        }
                        if let sc = score {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.06))
                                        .frame(height: 3)
                                    Capsule().fill(utilityColor(sc))
                                        .frame(width: geo.size.width * sc, height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    }
                }
            }

            // Urgency badge
            urgencyBadge(s.urgency)
                .frame(maxWidth: .infinity, alignment: .trailing)

            // Feedback slider (A ↔ B persona lean)
            if analysisTurns.count >= 2 {
                feedbackSliderSection(analysisTurns[0], analysisTurns[1])
            }

            Divider().background(Color.white.opacity(0.08))

            // Human-in-the-Loop section (if no consensus)
            if vm.debateNeedsHumanInput && !(vm.debateReverseQuestions.isEmpty) {
                humanInTheLoopSection
                Divider().background(Color.white.opacity(0.08))
            }

            // Continue chat buttons — one per active persona
            VStack(spacing: 6) {
                ForEach(vm.personas.prefix(3)) { persona in
                    if let pType = persona.personaType {
                        Button {
                            onDismiss()
                            vm.openSinglePersonaChat(personaType: pType)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: pType.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color(hex: pType.accentHex))
                                Text("\(pType.localizedName) 페르소나와 계속 대화")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.75))
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.white.opacity(0.35))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(hex: pType.accentHex).opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color(hex: pType.accentHex).opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Reset button
            Button {
                vm.resetDebate()
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9))
                    Text("처음부터 다시")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color.white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    // MARK: Utility bar color

    private func utilityColor(_ score: Double) -> Color {
        if score >= 0.75 { return Color(hex: "#22c55e") }
        if score >= 0.50 { return Color(hex: "#f59e0b") }
        return Color(hex: "#f43f5e")
    }

    // MARK: Feedback Slider

    private func feedbackSliderSection(_ turnA: AgentTurn, _ turnB: AgentTurn) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("어느 관점에 더 공감하시나요?", systemImage: "slider.horizontal.3")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 8) {
                Text(domainName(turnA.domain))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(domainAccent(turnA.domain))
                    .frame(width: 28, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { vm.debateFeedbackSlider },
                        set: { vm.debateFeedbackSlider = $0 }
                    ),
                    in: 0...1
                )
                .tint(
                    vm.debateFeedbackSlider < 0.5
                        ? domainAccent(turnA.domain)
                        : domainAccent(turnB.domain)
                )

                Text(domainName(turnB.domain))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(domainAccent(turnB.domain))
                    .frame(width: 28, alignment: .trailing)
            }

            let leaning: String = {
                let v = vm.debateFeedbackSlider
                if v < 0.35 { return "\(domainName(turnA.domain)) 관점 선호" }
                if v > 0.65 { return "\(domainName(turnB.domain)) 관점 선호" }
                return "두 관점 균형"
            }()
            Text(leaning)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 4)
    }

    // MARK: Human-in-the-Loop section

    private var humanInTheLoopSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#f59e0b").opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.2.wave.2")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#f59e0b"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("인간 판단이 필요합니다")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#f59e0b"))
                    Text("에이전트들이 합의에 도달하지 못했습니다")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            // Questions
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(vm.debateReverseQuestions.enumerated()), id: \.offset) { i, q in
                    HStack(alignment: .top, spacing: 8) {
                        Text("Q\(i + 1)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#f59e0b"))
                            .frame(width: 20, height: 16)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "#f59e0b").opacity(0.15))
                            )
                        Text(q)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: "#f59e0b").opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color(hex: "#f59e0b").opacity(0.18), lineWidth: 0.5)
                            )
                    )
                }
            }

            // Answer TextField — white background, black text for readability
            VStack(alignment: .leading, spacing: 4) {
                Text("내 답변")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))

                TextField("여기에 답변을 입력하세요…", text: Binding(
                    get: { vm.debateHumanAnswer },
                    set: { vm.debateHumanAnswer = $0 }
                ), axis: .vertical)
                .lineLimit(4...6)
                .font(.system(size: 12))
                .foregroundColor(.black)
                .colorScheme(.light)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(
                                    vm.debateHumanAnswer.isEmpty
                                        ? Color(hex: "#f59e0b").opacity(0.3)
                                        : Color(hex: "#f59e0b").opacity(0.6),
                                    lineWidth: 1
                                )
                        )
                )
            }

            // Action buttons
            HStack(spacing: 8) {
                let isEmpty = vm.debateHumanAnswer.trimmingCharacters(in: .whitespaces).isEmpty

                Button {
                    vm.submitDebateHumanAnswer()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 10))
                        Text("답변 제출")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(isEmpty ? Color.black.opacity(0.3) : Color.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(isEmpty
                            ? Color(hex: "#f59e0b").opacity(0.3)
                            : Color(hex: "#f59e0b"))
                    )
                }
                .buttonStyle(.plain)
                .disabled(isEmpty)

                Spacer()

                Button {
                    vm.resetDebate()
                    onDismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9))
                        Text("처음부터")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(Color.white.opacity(0.06))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#f59e0b").opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color(hex: "#f59e0b").opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func urgencyBadge(_ urgency: String) -> some View {
        let (label, color): (String, Color) = {
            switch urgency {
            case "immediate": return ("48시간 내 실행", Color(hex: "#f43f5e"))
            case "soon":      return ("1주 내 실행",   Color(hex: "#f59e0b"))
            default:          return ("지속 관찰",     Color(hex: "#3b82f6"))
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 0.5))
    }

    // MARK: Raw fallback (when JSON parse fails)

    private var rawFallback: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.activeDebateResult ?? "")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(showFullRaw ? nil : 8)
                .fixedSize(horizontal: false, vertical: true)
            if (vm.activeDebateResult?.count ?? 0) > 0 {
                Button {
                    showFullRaw.toggle()
                } label: {
                    Text(showFullRaw ? "접기" : "더보기")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(hex: "#64748b"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
    }

    // MARK: Background

    private var panelBackground: some View {
        Color(red: 0.07, green: 0.08, blue: 0.12)
    }

    // MARK: JSON parsing

    private func parseSynthesis(_ json: String) -> DebateSynthesisDisplay? {
        guard let start = json.firstIndex(of: "{"),
              let end   = json.lastIndex(of: "}") else { return nil }
        let clean = String(json[start...end])
        guard let data = clean.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DebateSynthesisDisplay.self, from: data)
    }
}

// MARK: - DebateSynthesisDisplay

private struct DebateSynthesisDisplay: Decodable {
    let rootCause: String
    let actions: [String]
    let actionScores: [Double]?
    let urgency: String
    let consensusReached: Bool?
    let reverseQuestions: [String]?
}

// MARK: - PersonaSuggestionBanner

/// Shown when NodeManagerAgent detects ≥10 nodes belonging to a PersonaType
/// that the user hasn't created yet.
struct PersonaSuggestionBanner: View {
    @Environment(GraphViewModel.self) private var vm
    let onAccept: (PersonaType) -> Void
    let onDismiss: () -> Void

    var body: some View {
        if let suggested = vm.pendingPersonaSuggestion {
            HStack(spacing: 10) {
                // Persona color dot
                Circle()
                    .fill(Color(hex: suggested.accentHex))
                    .frame(width: 8, height: 8)

                Image(systemName: suggested.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: suggested.accentHex))

                Text("\(suggested.localizedName) 페르소나를 만들어볼까요?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer(minLength: 0)

                // Accept button
                Button {
                    onAccept(suggested)
                } label: {
                    Text("만들기")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color(hex: suggested.accentHex))
                        )
                }
                .buttonStyle(.plain)

                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(suggestionBackground(accent: Color(hex: suggested.accentHex)))
            .shadow(color: Color(hex: suggested.accentHex).opacity(0.25), radius: 12)
        }
    }

    private func suggestionBackground(accent: Color) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.96))
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.6), accent.opacity(0.2)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        }
    }
}

// MARK: - Preview

#Preview("Status Banner") {
    DebateStatusBanner()
        .environment({
            let vm = GraphViewModel(modelContext: try! ModelContainer(for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self, DebateRecord.self).mainContext)
            vm.debateStatus = "AI 멀티 에이전트 분석 중..."
            return vm
        }())
        .padding(40)
        .background(Color(hex: "#020617"))
}
