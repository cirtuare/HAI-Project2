// LeftSidebarView.swift
// MemoAgent — Phase 3: Left Sidebar
//
// A native macOS sidebar that replaces LeftSidebar.tsx.
// Reads and writes exclusively through GraphViewModel.

import SwiftUI
import SwiftData

struct LeftSidebarView: View {
    @Environment(GraphViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        List {
            if !vm.personas.isEmpty {
                personaSection
            }
            viewModeSection
            filterSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
        .background(.regularMaterial)
    }

    // ─────────────────────────────────────────────
    // MARK: Persona Section (V2)
    // ─────────────────────────────────────────────

    private var personaSection: some View {
        Section {
            // "All" row — clears active persona
            personaRow(
                id: nil,
                name: "전체 보기",
                colorHex: "#64748b",
                icon: "globe",
                isActive: vm.activePersona == nil
            )
            ForEach(vm.personas, id: \.id) { persona in
                personaRow(
                    id: persona.id,
                    name: persona.name,
                    colorHex: persona.accentColorHex,
                    icon: persona.personaType?.icon ?? "person.fill",
                    isActive: vm.activePersona?.id == persona.id
                )
            }
        } header: {
            Text("PERSONA")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.8)
        }
    }

    private func personaRow(id: String?, name: String, colorHex: String, icon: String, isActive: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if let id, let persona = vm.personas.first(where: { $0.id == id }) {
                    vm.activatePersona(persona)
                } else {
                    vm.clearPersona()
                }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isActive ? Color(hex: colorHex) : Color.secondary)
                    .frame(width: 16)
                Text(name)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .primary : .secondary)
                Spacer()
                if isActive {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 6, height: 6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isActive ? Color(hex: colorHex).opacity(0.1) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    // ─────────────────────────────────────────────
    // MARK: View Mode Section
    // ─────────────────────────────────────────────

    private var viewModeSection: some View {
        Section {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                viewModeRow(mode)
            }
        } header: {
            Text("VIEW MODE")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.8)
        }
    }

    private func viewModeRow(_ mode: ViewMode) -> some View {
        @Bindable var vm = vm
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                vm.activeViewMode = mode
            }
        } label: {
            Label(mode.rawValue, systemImage: mode.systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(vm.activeViewMode == mode ? Color.cyan : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(vm.activeViewMode == mode
                      ? Color.cyan.opacity(0.12)
                      : Color.clear)
        )
        .animation(.easeInOut(duration: 0.15), value: vm.activeViewMode)
    }

    // ─────────────────────────────────────────────
    // MARK: Filter Section
    // ─────────────────────────────────────────────

    private var filterSection: some View {
        Section {
            ForEach(NodeType.allCases, id: \.self) { type in
                filterRow(type)
            }
        } header: {
            Label("FILTERS", systemImage: "line.3.horizontal.decrease")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.8)
        }
    }

    private func filterRow(_ type: NodeType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                vm.toggleTypeFilter(type)
            }
        } label: {
            HStack(spacing: 10) {
                // Coloured checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isOn(type) ? Color(hex: type.hexColor) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(isOn(type)
                                        ? Color.clear
                                        : Color.secondary.opacity(0.4),
                                        lineWidth: 1.5)
                        )
                        .frame(width: 16, height: 16)

                    if isOn(type) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                // Type icon + label
                Image(systemName: type.systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: type.hexColor))
                    .frame(width: 16)

                Text(type.localizedLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(isOn(type) ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
    }

    private func isOn(_ type: NodeType) -> Bool {
        vm.typeFilters[type] ?? true
    }
}

// MARK: - Color hex initialiser (used by sidebar chips)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    let container = try! ModelContainer(for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    LeftSidebarView()
        .environment(GraphViewModel(modelContext: container.mainContext))
}
