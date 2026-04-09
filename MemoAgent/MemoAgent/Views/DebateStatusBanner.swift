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

    private var synthesis: DebateSynthesisDisplay? {
        guard let json = vm.activeDebateResult else { return nil }
        return parseSynthesis(json)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            if let s = synthesis {
                content(s)
            } else {
                rawFallback
            }
        }
        .frame(width: 300)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: "#f97316").opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
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

            // Action items
            VStack(alignment: .leading, spacing: 6) {
                Label("실행 계획", systemImage: "checklist")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#22c55e"))

                ForEach(Array(s.actions.enumerated()), id: \.offset) { i, action in
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
                    }
                }
            }

            // Urgency badge
            urgencyBadge(s.urgency)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
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
        Text(vm.activeDebateResult ?? "")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.6))
            .lineLimit(8)
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
    let urgency: String
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
