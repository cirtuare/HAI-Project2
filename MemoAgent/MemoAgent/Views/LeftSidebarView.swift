// LeftSidebarView.swift
// MemoAgent — Phase 3: Left Sidebar
//
// A native macOS sidebar that replaces LeftSidebar.tsx.
// Reads and writes exclusively through GraphViewModel.

import SwiftUI

struct LeftSidebarView: View {
    @Environment(GraphViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm

        List {
            viewModeSection
            filterSection
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
        // Sidebar background: thin material tinted to match dark surface-primary
        .background(.regularMaterial)
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
    LeftSidebarView()
        .environment(GraphViewModel())
}
