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

        // ── Trailing: Sync status + Chat + Settings + Add data ──────────────────
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 8) {
                syncStatusButton
                chatButton
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

    private var syncStatusButton: some View {
        Group {
            if vm.isSyncing {
                HStack(spacing: 5) {
                    ProgressView().scaleEffect(0.6).tint(.cyan)
                    Text("동기화 중")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.cyan.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.cyan.opacity(0.2), lineWidth: 0.5))
                )
            } else if let date = vm.lastSyncDate {
                Button { vm.triggerEcosystemSync() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                        Text(relativeTime(date))
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help("마지막 동기화: \(date.formatted())")
            } else if vm.activePersona != nil {
                Button { vm.triggerEcosystemSync() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help("Apple 생태계 동기화")
            }
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "방금" }
        if diff < 3600 { return "\(diff / 60)분 전" }
        return "\(diff / 3600)시간 전"
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

    private var chatButton: some View {
        Button {
            vm.openChat()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 12, weight: .medium))
                if let persona = vm.activePersona {
                    Circle()
                        .fill(Color(hex: persona.accentColorHex))
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundStyle(vm.isChatPresented ? Color.cyan : Color.white.opacity(0.55))
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        vm.isChatPresented
                            ? Color.cyan.opacity(0.15)
                            : Color.primary.opacity(0.07)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                vm.isChatPresented
                                    ? Color.cyan.opacity(0.4)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .help("페르소나 채팅")
        .keyboardShortcut("k", modifiers: [.command, .shift])
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
