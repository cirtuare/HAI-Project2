// OriginView.swift
// MemoAgent — Origin View Mode
//
// Shows all knowledge nodes grouped by their source type (memo/pdf/diary/chat).
// Each group displays its count and an expandable list of nodes.
// Selecting a node opens the detail inspector.

import SwiftUI
import SwiftData

struct OriginView: View {
    @Environment(GraphViewModel.self) private var vm

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                header

                // Summary bar — counts per type
                summaryBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                // One section per NodeType
                ForEach(NodeType.allCases, id: \.self) { type in
                    let nodes = vm.nodes.filter { $0.type == type }
                    if !nodes.isEmpty {
                        OriginGroupSection(type: type, nodes: nodes)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                    }
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
                Image(systemName: "doc.text")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text("Origin View")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            Text("지식 블록을 출처 유형별로 분류합니다.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 20)
    }

    // ─────────────────────────────────────────────
    // MARK: Summary Bar
    // ─────────────────────────────────────────────

    private var summaryBar: some View {
        HStack(spacing: 12) {
            ForEach(NodeType.allCases, id: \.self) { type in
                let count = vm.nodes.filter { $0.type == type }.count
                OriginTypeChip(type: type, count: count)
            }
            Spacer()
        }
    }
}

// MARK: - OriginTypeChip

private struct OriginTypeChip: View {
    let type: NodeType
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: type.systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: type.hexColor))
            Text(type.localizedLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: type.hexColor))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(hex: type.hexColor).opacity(0.1))
                .overlay(
                    Capsule().strokeBorder(Color(hex: type.hexColor).opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - OriginGroupSection

private struct OriginGroupSection: View {
    @Environment(GraphViewModel.self) private var vm
    let type: NodeType
    let nodes: [GraphNode]
    @State private var isExpanded = true

    private let accentColor: Color

    init(type: NodeType, nodes: [GraphNode]) {
        self.type = type
        self.nodes = nodes
        self.accentColor = Color(hex: type.hexColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: type.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(accentColor.opacity(0.15))
                        )

                    Text(type.localizedLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))

                    Text("\(nodes.count)개")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(accentColor.opacity(0.12)))

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(accentColor.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(.plain)

            // Node rows
            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(nodes) { node in
                        OriginNodeRow(node: node, accentColor: accentColor)
                    }
                }
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - OriginNodeRow

private struct OriginNodeRow: View {
    @Environment(GraphViewModel.self) private var vm
    let node: GraphNode
    let accentColor: Color

    @State private var isHovered = false

    var isSelected: Bool { vm.selectedNodeIDs.contains(node.id) }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                vm.selectNode(node.id)
            }
        } label: {
            HStack(spacing: 12) {
                // Importance indicator
                if node.isImportant {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(hex: "#f59e0b"))
                } else {
                    Color.clear.frame(width: 9)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            isSelected
                                ? accentColor
                                : Color.white.opacity(0.88)
                        )
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(node.date)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.4))

                        if !node.tags.isEmpty {
                            Text(node.tags.prefix(2).joined(separator: "  ·  "))
                                .font(.system(size: 11))
                                .foregroundStyle(accentColor.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(isHovered ? 0.5 : 0.2))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        isSelected
                            ? accentColor.opacity(0.12)
                            : (isHovered ? Color.white.opacity(0.04) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                isSelected ? accentColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
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
    let container = try! ModelContainer(for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    OriginView()
        .environment(GraphViewModel(modelContext: container.mainContext))
        .frame(width: 800, height: 600)
}
