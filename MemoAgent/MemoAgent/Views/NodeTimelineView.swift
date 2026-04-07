// NodeTimelineView.swift
// MemoAgent — Timeline View Mode
//
// Shows all knowledge nodes in reverse-chronological order.
// Nodes are grouped by month (YYYY-MM) with a vertical timeline decoration.
// Selecting a node opens the detail inspector.

import SwiftUI

struct NodeTimelineView: View {
    @Environment(GraphViewModel.self) private var vm

    /// Nodes sorted newest-first, with optional search filter applied.
    private var sortedNodes: [GraphNode] {
        vm.nodes
            .filter { node in
                guard vm.typeFilters[node.type] == true else { return false }
                if vm.searchQuery.isEmpty { return true }
                let q = vm.searchQuery.lowercased()
                return node.title.lowercased().contains(q)
                    || node.summary.lowercased().contains(q)
            }
            .sorted { $0.date > $1.date }
    }

    /// Nodes grouped by their YYYY-MM prefix.
    private var groupedByMonth: [(key: String, nodes: [GraphNode])] {
        var dict: [String: [GraphNode]] = [:]
        for node in sortedNodes {
            let key = String(node.date.prefix(7))  // "2024-01"
            dict[key, default: []].append(node)
        }
        return dict.sorted { $0.key > $1.key }.map { (key: $0.key, nodes: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if groupedByMonth.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedByMonth, id: \.key) { group in
                        TimelineMonthSection(monthKey: group.key, nodes: group.nodes)
                            .padding(.horizontal, 24)
                    }
                    // Bottom spacer
                    Spacer().frame(height: 32)
                }
            }
        }
        .background(Color(hex: "#020617"))
        .colorScheme(.dark)
    }

    // ─────────────────────────────────────────────
    // MARK: Header
    // ─────────────────────────────────────────────

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text("Timeline View")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            Text("지식 블록을 시간 순서대로 탐색합니다.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
    }

    // ─────────────────────────────────────────────
    // MARK: Empty State
    // ─────────────────────────────────────────────

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(Color.white.opacity(0.2))
            Text("표시할 노드가 없습니다.")
                .font(.system(size: 14))
                .foregroundStyle(Color.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - TimelineMonthSection

private struct TimelineMonthSection: View {
    @Environment(GraphViewModel.self) private var vm
    let monthKey: String
    let nodes: [GraphNode]

    private var displayMonth: String {
        let parts = monthKey.split(separator: "-")
        if parts.count == 2, let year = parts.first, let month = Int(parts.last ?? "") {
            let months = ["1월","2월","3월","4월","5월","6월",
                          "7월","8월","9월","10월","11월","12월"]
            let name = month >= 1 && month <= 12 ? months[month - 1] : monthKey
            return "\(year)년 \(name)"
        }
        return monthKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Month header
            HStack(spacing: 10) {
                // Timeline dot
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Color.cyan.opacity(0.3), lineWidth: 4))

                Text(displayMonth)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .kerning(0.3)

                Spacer()

                Text("\(nodes.count)개")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .padding(.top, 24)
            .padding(.bottom, 12)

            // Timeline entries
            HStack(alignment: .top, spacing: 0) {
                // Vertical line
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                }
                .padding(.leading, 4)
                .frame(width: 14)

                // Node cards
                VStack(spacing: 8) {
                    ForEach(nodes) { node in
                        TimelineNodeCard(node: node)
                    }
                }
                .padding(.leading, 12)
            }
        }
    }
}

// MARK: - TimelineNodeCard

private struct TimelineNodeCard: View {
    @Environment(GraphViewModel.self) private var vm
    let node: GraphNode

    @State private var isHovered = false

    private var style: NodeTypeStyle { NodeTypeStyle.style(for: node.type) }
    private var isSelected: Bool { vm.selectedNodeIDs.contains(node.id) }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                vm.selectNode(node.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Type icon
                Image(systemName: style.systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(style.accentColor)
                    .frame(width: 26, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(style.bgColor.opacity(0.3))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(node.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(
                                isSelected ? style.accentColor : Color.white.opacity(0.9)
                            )
                            .lineLimit(1)

                        if node.isImportant {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "#f59e0b"))
                        }

                        Spacer()

                        Text(node.date)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }

                    Text(node.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if !node.tags.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(node.tags.prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(style.accentColor.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? style.accentColor.opacity(0.1)
                            : (isHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isSelected
                                    ? style.accentColor.opacity(0.4)
                                    : Color.white.opacity(0.08),
                                lineWidth: isSelected ? 1 : 0.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    vm.deleteNode(id: node.id)
                }
            } label: {
                Label("노드 삭제", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NodeTimelineView()
        .environment(GraphViewModel())
        .frame(width: 800, height: 600)
}
