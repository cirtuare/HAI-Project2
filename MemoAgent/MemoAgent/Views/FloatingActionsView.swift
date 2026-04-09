// FloatingActionsView.swift
// MemoAgent — Phase 4: Floating Actions Bar
//
// Mirrors FloatingActions.tsx: appears when ≥2 nodes are selected,
// spring-animates in/out, offers connect / disconnect / prompt actions.

import SwiftUI

struct FloatingActionsView: View {
    @Environment(GraphViewModel.self) private var vm

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if vm.selectedNodeIDs.count > 1 {
                    actionBar
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.88, anchor: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 16)),
                                removal:   .scale(scale: 0.88, anchor: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 16))
                            )
                        )
                }
                Spacer()
            }
            .padding(.bottom, 28)
        }
        .animation(
            .spring(response: 0.35, dampingFraction: 0.72),
            value: vm.selectedNodeIDs.count
        )
        .allowsHitTesting(vm.selectedNodeIDs.count > 1)
    }

    // ─────────────────────────────────────────────
    // MARK: Bar
    // ─────────────────────────────────────────────

    private var actionBar: some View {
        HStack(spacing: 0) {
            // Selection count badge
            HStack(spacing: 4) {
                Text("\(vm.selectedNodeIDs.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("개 선택됨")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().frame(height: 24)

            // Connect
            actionButton(
                label: "연결",
                icon: "link",
                accentColor: .cyan
            ) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    vm.connectSelectedNodes()
                }
            }

            // Disconnect
            actionButton(
                label: "끊기",
                icon: "link.badge.minus",
                accentColor: Color(hex: "#f43f5e")
            ) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    vm.disconnectSelectedNodes()
                }
            }

            // Divider before primary action
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1, height: 24)
                .padding(.horizontal, 4)

            // Prompt composer (primary CTA)
            promptButton
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // ─────────────────────────────────────────────
    // MARK: Buttons
    // ─────────────────────────────────────────────

    private func actionButton(
        label: String,
        icon: String,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accentColor)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var promptButton: some View {
        Button {
            // Selecting 2+ nodes + pressing this implicitly opens the inspector;
            // isInspectorPresented is driven by selectedNodeIDs being non-empty.
            // We just need to ensure at least one node is selected (already true).
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Text("프롬프트 뽑기")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#7c3aed"))  // violet-700
                    .shadow(color: Color(hex: "#8b5cf6").opacity(0.35), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var vm: GraphViewModel = {
            let vm = GraphViewModel()
            vm.selectNode("1")
            vm.toggleSelection(of: "2")
            vm.toggleSelection(of: "3")
            return vm
        }()
        var body: some View {
            ZStack {
                Color(hex: "#020617")
                FloatingActionsView()
                    .environment(vm)
            }
            .frame(width: 700, height: 400)
        }
    }
    return PreviewWrapper()
}
