// PersonaOnboardingView.swift
// MemoAgent V2 — First-launch persona selection screen

import SwiftUI

struct PersonaOnboardingView: View {
    @Environment(GraphViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<PersonaType> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 24) {
                    subtitle
                    personaGrid
                }
                .padding(32)
            }
            Divider()
            footer
        }
        .frame(width: 600, height: 560)
        .background(Color(hex: "#0f172a"))
        .colorScheme(.dark)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.cyan.opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("NodeMind에 오신 것을 환영합니다")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text("어떤 분야의 지식을 관리하실 건가요?")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    // MARK: - Subtitle

    private var subtitle: some View {
        VStack(spacing: 6) {
            Text("페르소나를 선택하면 AI가 해당 분야에 맞게 데이터를 필터링하고 분석합니다.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Text("여러 개 선택 가능 · 나중에 설정에서 변경 가능")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }

    // MARK: - Grid

    private var personaGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PersonaType.allCases, id: \.self) { type in
                personaCard(type)
            }
        }
    }

    private func personaCard(_ type: PersonaType) -> some View {
        let isOn = selected.contains(type)
        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                if isOn { selected.remove(type) } else { selected.insert(type) }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: type.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isOn ? Color(hex: type.accentHex) : Color.white.opacity(0.4))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isOn
                                  ? Color(hex: type.accentHex).opacity(0.15)
                                  : Color.white.opacity(0.05))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.localizedName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isOn ? Color.white.opacity(0.92) : Color.white.opacity(0.6))
                    Text(type.description)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: type.accentHex))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? Color(hex: type.accentHex).opacity(0.06) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isOn ? Color(hex: type.accentHex).opacity(0.5) : Color.white.opacity(0.07),
                                lineWidth: isOn ? 1.5 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isOn)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("나중에 설정") {
                dismiss()
                vm.showingPersonaOnboarding = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Color.white.opacity(0.35))

            Spacer()

            Button {
                vm.finishOnboarding(selected: Array(selected))
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text(selected.isEmpty ? "기본 설정으로 시작" : "\(selected.count)개 페르소나로 시작")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(selected.isEmpty ? Color.white.opacity(0.15) : Color.cyan)
                        .shadow(color: selected.isEmpty ? .clear : .cyan.opacity(0.3), radius: 8, y: 2)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }
}

#Preview {
    PersonaOnboardingView()
        .environment(GraphViewModel(modelContext: {
            let container = try! ModelContainer(for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self)
            return container.mainContext
        }()))
}
