// LeftSidebarView.swift
// MemoAgent — Phase 3: Left Sidebar
//
// A native macOS sidebar that replaces LeftSidebar.tsx.
// Reads and writes exclusively through GraphViewModel.

import SwiftUI
import SwiftData

struct LeftSidebarView: View {
    @Environment(GraphViewModel.self) private var vm

    @State private var isAddingPersona  = false
    @State private var editingPersona: PersonaRecord? = nil
    @State private var deletingPersona: PersonaRecord? = nil

    var body: some View {
        @Bindable var vm = vm

        List {
            personaSection
            viewModeSection
            filterSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
        .background(.regularMaterial)
        .sheet(isPresented: $isAddingPersona) {
            PersonaEditSheet()
                .environment(vm)
        }
        .sheet(item: $editingPersona) { persona in
            PersonaEditSheet(editing: persona)
                .environment(vm)
        }
        .confirmationDialog(
            "페르소나 삭제",
            isPresented: Binding(
                get: { deletingPersona != nil },
                set: { if !$0 { deletingPersona = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let persona = deletingPersona {
                Button("\(persona.name) 삭제", role: .destructive) {
                    vm.deletePersona(id: persona.id)
                    deletingPersona = nil
                }
                Button("취소", role: .cancel) { deletingPersona = nil }
            }
        } message: {
            if let persona = deletingPersona {
                Text("\(persona.name) 페르소나를 삭제하면 연결된 노드의 페르소나 지정이 모두 해제됩니다.")
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Persona Section (V2)
    // ─────────────────────────────────────────────

    private var personaSection: some View {
        Section {
            // "All" row — clears active persona (no context menu)
            personaRow(id: nil, name: "전체 보기",
                       colorHex: "#64748b", icon: "globe",
                       isActive: vm.activePersona == nil,
                       nodeCount: vm.nodes.count)
            ForEach(vm.personas, id: \.id) { persona in
                personaRow(
                    id: persona.id,
                    name: persona.name,
                    colorHex: persona.accentColorHex,
                    icon: persona.personaType?.icon ?? "person.fill",
                    isActive: vm.activePersona?.id == persona.id,
                    nodeCount: vm.nodes.filter { $0.personaIDs.contains(persona.id) }.count,
                    personaType: persona.personaType
                )
                .contextMenu {
                    Button {
                        editingPersona = persona
                    } label: {
                        Label("이름 변경", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        deletingPersona = persona
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack {
                Text("PERSONA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.8)
                Spacer()
                // Persona count
                if !vm.personas.isEmpty {
                    Text("\(vm.personas.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .padding(.trailing, 4)
                }
                // Add persona button
                Button {
                    isAddingPersona = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .frame(width: 18, height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .help("페르소나 추가")
            }
        }
    }

    private func personaRow(id: String?, name: String, colorHex: String, icon: String,
                             isActive: Bool, nodeCount: Int,
                             personaType: PersonaType? = nil) -> some View {
        let accent = Color(hex: colorHex)
        return HStack(spacing: 0) {
            // Tap to activate persona filter
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
                    // Color badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isActive ? accent : accent.opacity(0.18))
                            .frame(width: 24, height: 24)
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isActive ? .white : accent)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                            .foregroundStyle(isActive ? .primary : .secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    // Node count badge
                    if nodeCount > 0 {
                        Text("\(nodeCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isActive ? accent : Color.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(isActive ? accent.opacity(0.15) : Color.clear))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Quick 1:1 chat button (only for real personas, not "전체 보기")
            if let pType = personaType {
                Button {
                    vm.openSinglePersonaChat(personaType: pType)
                } label: {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(accent.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(accent.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
                .help("\(name) 페르소나와 1:1 채팅")
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? accent.opacity(0.08) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isActive ? accent.opacity(0.25) : Color.clear, lineWidth: 1)
                )
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
