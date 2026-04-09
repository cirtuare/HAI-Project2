// ToolbarContent.swift
// MemoAgent — Phase 3: macOS Toolbar
//
// Replaces GlobalNav.tsx.
// All toolbar items bind to GraphViewModel via @Environment.

import SwiftUI

// MARK: - NodeMindToolbar

/// A `ToolbarContent` group that populates the unified toolbar.
/// Installed on the root view via `.toolbar { NodeMindToolbar() }`.
struct NodeMindToolbar: ToolbarContent {
    @Environment(GraphViewModel.self) private var vm

    var body: some ToolbarContent {
        // ── Leading: Logo + title ────────────────────────────────────────
        ToolbarItem(placement: .navigation) {
            logoView
        }

        // ── Centre: Search field ─────────────────────────────────────────
        ToolbarItem(placement: .principal) {
            searchField
        }

        // ── Trailing: Settings + Add data ────────────────────────────────
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 8) {
                settingsButton
                addDataButton
            }
        }
    }

    // MARK: Sub-views

    private var logoView: some View {
        HStack(spacing: 6) {
            Image(systemName: "network")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.cyan)
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.cyan.opacity(0.15))
                )
            Text("NodeMind")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
        }
    }

    private var searchField: some View {
        @Bindable var vm = vm
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(vm.searchQuery.isEmpty ? Color.secondary : Color.cyan)
                .font(.system(size: 13))

            TextField("지식을 검색하세요...", text: $vm.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .frame(minWidth: 240, idealWidth: 360)

            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.background.secondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            vm.searchQuery.isEmpty
                                ? Color.primary.opacity(0.1)
                                : Color.cyan.opacity(0.5),
                            lineWidth: 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.15), value: vm.searchQuery.isEmpty)
    }

    private var settingsButton: some View {
        Button {
            vm.isSettingsPresented = true
        } label: {
            Image(systemName: "cpu")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(
                    AIProviderManager.shared.selectedProvider == .claudeAPI
                        ? Color.cyan
                        : Color.secondary
                )
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            AIProviderManager.shared.selectedProvider == .claudeAPI
                                ? Color.cyan.opacity(0.12)
                                : Color.primary.opacity(0.07)
                        )
                )
        }
        .buttonStyle(.plain)
        .help("AI 설정")
        .keyboardShortcut(",", modifiers: [.command])
    }

    private var addDataButton: some View {
        Button {
            vm.openAddModal()
        } label: {
            Label("데이터 추가", systemImage: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.cyan)
                        .shadow(color: .cyan.opacity(0.3), radius: 6, y: 2)
                )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("n", modifiers: [.command, .shift])
    }
}
