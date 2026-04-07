// NodeCardView.swift
// MemoAgent — Phase 4: Node Card
//
// Renders a single knowledge node on the canvas.
// Mirrors CustomNode.tsx: type-coloured border, icon, title, summary, tags,
// importance sparkle, hover tooltip, selected ring.
// Drag is handled by GraphCanvasView and routed through GraphViewModel.

import SwiftUI

// MARK: - NodeTypeStyle

/// All visual tokens for a node type, mirroring `typeConfig` in CustomNode.tsx.
struct NodeTypeStyle {
    let accentColor: Color
    let bgColor: Color
    let systemImage: String

    static func style(for type: NodeType) -> NodeTypeStyle {
        switch type {
        case .memo:
            return NodeTypeStyle(
                accentColor: Color(hex: "#06b6d4"),   // cyan-500
                bgColor:     Color(hex: "#06b6d4").opacity(0.10),
                systemImage: "doc.text"
            )
        case .pdf:
            return NodeTypeStyle(
                accentColor: Color(hex: "#f43f5e"),   // rose-500
                bgColor:     Color(hex: "#f43f5e").opacity(0.10),
                systemImage: "doc.fill"
            )
        case .diary:
            return NodeTypeStyle(
                accentColor: Color(hex: "#f59e0b"),   // amber-500
                bgColor:     Color(hex: "#f59e0b").opacity(0.10),
                systemImage: "book.closed"
            )
        case .chat:
            return NodeTypeStyle(
                accentColor: Color(hex: "#8b5cf6"),   // violet-500
                bgColor:     Color(hex: "#8b5cf6").opacity(0.10),
                systemImage: "message"
            )
        }
    }
}

// MARK: - NodeCardView

struct NodeCardView: View {
    let node: GraphNode
    let isSelected: Bool
    /// True when this card is the hover-target during a connection drag.
    var isConnectionTarget: Bool = false
    let searchOpacity: Double

    /// Called by the canvas when the user clicks (without dragging).
    var onTap: () -> Void = {}
    /// Called by the canvas when ⌘-click occurs.
    var onCommandTap: () -> Void = {}
    /// Called when the user selects "삭제" from the context menu.
    var onDelete: () -> Void = {}

    @State private var isHovered = false
    @State private var isDragging = false

    private let style: NodeTypeStyle
    private let cardWidth: CGFloat

    init(node: GraphNode, isSelected: Bool, isConnectionTarget: Bool = false,
         searchOpacity: Double,
         onTap: @escaping () -> Void = {},
         onCommandTap: @escaping () -> Void = {},
         onDelete: @escaping () -> Void = {}) {
        self.node = node
        self.isSelected = isSelected
        self.isConnectionTarget = isConnectionTarget
        self.searchOpacity = searchOpacity
        self.onTap = onTap
        self.onCommandTap = onCommandTap
        self.onDelete = onDelete
        self.style = NodeTypeStyle.style(for: node.type)
        self.cardWidth = node.isImportant ? 240 : 210
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            card
            if node.isImportant {
                importanceBadge
            }
        }
        // Hover tooltip appears below the card
        .overlay(alignment: .top) {
            if isHovered && !isSelected {
                tooltip
                    .offset(y: -tooltipHeight - 8)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.95, anchor: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: 8)),
                            removal:   .scale(scale: 0.95, anchor: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .offset(y: 8))
                        )
                    )
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.2, dampingFraction: 0.75), value: isHovered)
        .opacity(searchOpacity)
        .animation(.easeInOut(duration: 0.2), value: searchOpacity)
        .scaleEffect(isHovered && !isSelected ? 1.025 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("노드 삭제", systemImage: "trash")
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Card body
    // ─────────────────────────────────────────────

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon + title + summary row
            HStack(alignment: .top, spacing: 10) {
                iconView

                VStack(alignment: .leading, spacing: 3) {
                    Text(node.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(node.summary)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            // Tags
            if !node.tags.isEmpty {
                tagStrip
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .overlay(alignment: .top) {
                        Divider()
                    }
            } else {
                Spacer().frame(height: 10)
            }
        }
        .frame(width: cardWidth)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(
            color: isConnectionTarget ? Color.cyan.opacity(0.45)
                : isSelected          ? style.accentColor.opacity(0.35)
                :                       Color.black.opacity(0.2),
            radius: (isSelected || isConnectionTarget) ? 14 : 6,
            y: 3
        )
    }

    private var iconView: some View {
        Image(systemName: style.systemImage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(style.accentColor)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(style.bgColor)
            )
    }

    @ViewBuilder
    private var tagStrip: some View {
        let displayTags = Array(node.tags.prefix(3))
        let overflow = node.tags.count - displayTags.count

        FlowLayout(spacing: 4) {
            ForEach(displayTags, id: \.self) { tag in
                tagChip(tag)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.horizontal, 4)
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "number")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(style.accentColor.opacity(0.7))
            Text(tag)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(style.accentColor)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(style.bgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(style.accentColor.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(hex: "#1e293b"))  // slate-800 solid card surface
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(style.bgColor.opacity(0.35))
            )
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isConnectionTarget ? Color.cyan
                    : isSelected    ? style.accentColor
                    :                 style.accentColor.opacity(0.3),
                lineWidth: (isSelected || isConnectionTarget) ? 2 : 1
            )
    }

    // ─────────────────────────────────────────────
    // MARK: Importance badge
    // ─────────────────────────────────────────────

    private var importanceBadge: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Color(hex: "#f59e0b"))
            .padding(4)
            .background(
                Circle()
                    .fill(.regularMaterial)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            )
            .offset(x: 6, y: -6)
    }

    // ─────────────────────────────────────────────
    // MARK: Hover tooltip
    // ─────────────────────────────────────────────

    private let tooltipHeight: CGFloat = 0  // tooltip anchors to card top via offset

    private var tooltip: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type badge + date
            HStack(spacing: 6) {
                Text(node.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(style.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(style.bgColor)
                    )
                HStack(spacing: 3) {
                    Image(systemName: "calendar")
                        .font(.system(size: 9))
                    Text(node.date)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.tertiary)
            }

            Text(node.title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)

            Text(node.summary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !node.tags.isEmpty {
                Divider()
                FlowLayout(spacing: 4) {
                    ForEach(node.tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#1e293b"))  // slate-800 — solid readable surface
                .shadow(color: .black.opacity(0.5), radius: 16, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .colorScheme(.dark)
    }
}

// MARK: - FlowLayout

/// A simple left-to-right wrapping layout (replaces CSS flex-wrap).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                totalHeight = y
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        NodeCardView(
            node: sampleNodes[0],
            isSelected: false,
            searchOpacity: 1.0
        )
        NodeCardView(
            node: sampleNodes[1],
            isSelected: true,
            searchOpacity: 1.0
        )
        NodeCardView(
            node: sampleNodes[2],
            isSelected: false,
            searchOpacity: 0.15
        )
    }
    .padding(40)
    .background(Color(hex: "#020617"))
}
