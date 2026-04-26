// LiveDebateView.swift
// MemoAgent — Phase 5: Real-time Multi-Agent Debate Visualization
//
// Step C in the multi-persona flow: shows each AgentTurn as a colored bubble
// streamed live while DebateOrchestrator runs. Closes automatically when
// debate completes and the DebateResultPanel slides in.

import SwiftUI
import SwiftData

struct LiveDebateView: View {
    @Environment(GraphViewModel.self) private var vm

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            turnList
            if vm.debateStatus == nil {
                Divider().background(Color.white.opacity(0.08))
                completeFooter
            }
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 460, maxHeight: .infinity)
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
    // MARK: Header
    // ─────────────────────────────────────────────

    private var header: some View {
        HStack(spacing: 10) {
            // Animated orb (while debate is running)
            if vm.debateStatus != nil {
                DebateOrbView()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.debateStatus != nil ? "AI 멀티 에이전트 토론 진행 중" : "토론 완료")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                if let status = vm.debateStatus {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.45))
                } else {
                    Text("\(vm.liveDebateTurns.count)개 분석 완료")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }

            Spacer()

            Button {
                vm.isLiveDebatePresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#f97316").opacity(vm.debateStatus != nil ? 0.08 : 0.0),
                    Color.clear
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .animation(.easeInOut(duration: 0.5), value: vm.debateStatus == nil)
    }

    // ─────────────────────────────────────────────
    // MARK: Turn List
    // ─────────────────────────────────────────────

    private var turnList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if vm.liveDebateTurns.isEmpty {
                        waitingState
                    }
                    ForEach(Array(vm.liveDebateTurns.enumerated()), id: \.offset) { idx, turn in
                        DebateTurnBubble(turn: turn, index: idx)
                            .id(idx)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    // Typing indicator while next turn loads
                    if vm.debateStatus != nil && !vm.liveDebateTurns.isEmpty {
                        DebateTypingRow()
                            .id("typing")
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.spring(response: 0.35, dampingFraction: 0.8),
                           value: vm.liveDebateTurns.count)
            }
            .onChange(of: vm.liveDebateTurns.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    let last = vm.liveDebateTurns.count - 1
                    if last >= 0 { proxy.scrollTo(last, anchor: .bottom) }
                }
            }
            .onChange(of: vm.debateStatus) {
                if vm.debateStatus != nil {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    private var waitingState: some View {
        HStack(spacing: 12) {
            ProgressView().scaleEffect(0.7).tint(Color(hex: "#f97316"))
            Text("에이전트 초기화 중...")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // ─────────────────────────────────────────────
    // MARK: Complete Footer
    // ─────────────────────────────────────────────

    private var completeFooter: some View {
        HStack(spacing: 12) {
            Text("토론이 완료되었습니다. 결과 패널을 확인하세요.")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.5))
            Spacer()
            Button {
                vm.isLiveDebatePresented = false
            } label: {
                Text("결과 보기")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color(hex: "#f97316"))
                            .shadow(color: Color(hex: "#f97316").opacity(0.3), radius: 6, y: 2)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
    }
}

// MARK: - DebateTurnBubble

private struct DebateTurnBubble: View {
    let turn: AgentTurn
    let index: Int

    // Alternate sides: even index = left, odd = right
    private var isLeft: Bool { index % 2 == 0 }
    private var roleLabel: String {
        switch turn.role {
        case "analysis":  return "분석"
        case "rebuttal":  return "반론"
        case "synthesis": return "종합"
        default:          return turn.role
        }
    }
    private var accent: Color { domainColor(turn.domain) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if !isLeft { Spacer(minLength: 40) }

            VStack(alignment: isLeft ? .leading : .trailing, spacing: 4) {
                // Agent label + role badge
                HStack(spacing: 6) {
                    if isLeft {
                        agentIcon
                        agentLabel
                        roleBadge
                        Spacer()
                    } else {
                        Spacer()
                        roleBadge
                        agentLabel
                        agentIcon
                    }
                }

                // Content bubble
                Text(turn.content.prefix(300) + (turn.content.count > 300 ? "..." : ""))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accent.opacity(0.09))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(accent.opacity(0.25), lineWidth: 0.5)
                            )
                    )
                    .fixedSize(horizontal: false, vertical: true)

                // Confidence
                if turn.confidence > 0 {
                    Text("신뢰도 \(Int(turn.confidence * 100))%")
                        .font(.system(size: 9))
                        .foregroundStyle(accent.opacity(0.6))
                }
            }

            if isLeft { Spacer(minLength: 40) }
        }
        .padding(.vertical, 6)
    }

    private var agentIcon: some View {
        ZStack {
            Circle().fill(accent.opacity(0.15)).frame(width: 24, height: 24)
            Image(systemName: domainIcon(turn.domain))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    private var agentLabel: some View {
        Text(domainName(turn.domain))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(accent)
    }

    private var roleBadge: some View {
        Text(roleLabel)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(accent.opacity(0.15)))
    }
}

// MARK: - DebateTypingRow

private struct DebateTypingRow: View {
    @State private var phase: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(hex: "#f97316").opacity(0.6 + sin(phase + Double(i)) * 0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - DebateOrbView

private struct DebateOrbView: View {
    @State private var spinAngle: Double = 0

    var body: some View {
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
                .rotationEffect(.degrees(spinAngle))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                spinAngle = 360
            }
        }
    }
}

// MARK: - Domain helpers

private func domainColor(_ domain: String) -> Color {
    switch domain {
    case "health":     return Color(hex: "#1D9E75")
    case "academic":   return Color(hex: "#7F77DD")
    case "finance":    return Color(hex: "#EF9F27")
    case "hobby":      return Color(hex: "#D85A30")
    case "synthesizer": return Color(hex: "#f97316")
    default:           return Color(hex: "#64748b")
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
    case "health":      return "heart.fill"
    case "work":        return "briefcase.fill"
    case "academic":    return "book.fill"
    case "finance":     return "dollarsign.circle.fill"
    case "hobby":       return "star.fill"
    case "synthesizer": return "brain"
    default:            return "circle.fill"
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
    vm.isLiveDebatePresented = true
    vm.debateStatus = "건강 분석 완료"
    vm.liveDebateTurns = [
        AgentTurn(agentID: "health", role: "analysis", domain: "health",
                  content: "수면 부족과 스트레스 호르몬 상승이 연동되는 패턴이 감지됩니다. 특히 수요일~목요일 구간에서 심박변이율이 15% 이상 감소합니다.",
                  confidence: 0.82, timestamp: Date()),
        AgentTurn(agentID: "finance", role: "analysis", domain: "finance",
                  content: "월말 지출 집중 패턴이 관찰됩니다. 충동 구매 빈도가 스트레스 지수와 0.73의 상관관계를 보입니다.",
                  confidence: 0.80, timestamp: Date()),
    ]
    return LiveDebateView()
        .environment(vm)
        .modelContainer(container)
}
