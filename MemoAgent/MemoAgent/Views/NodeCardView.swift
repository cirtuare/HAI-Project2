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
        // ── V1 types ──────────────────────────────
        case .memo:
            return NodeTypeStyle(accentColor: Color(hex: "#06b6d4"), bgColor: Color(hex: "#06b6d4").opacity(0.10), systemImage: "doc.text")
        case .pdf:
            return NodeTypeStyle(accentColor: Color(hex: "#f43f5e"), bgColor: Color(hex: "#f43f5e").opacity(0.10), systemImage: "doc.fill")
        case .diary:
            return NodeTypeStyle(accentColor: Color(hex: "#f59e0b"), bgColor: Color(hex: "#f59e0b").opacity(0.10), systemImage: "book.closed")
        case .chat:
            return NodeTypeStyle(accentColor: Color(hex: "#8b5cf6"), bgColor: Color(hex: "#8b5cf6").opacity(0.10), systemImage: "message")
        // ── V2 Apple ecosystem types ──────────────
        case .healthMetric:
            return NodeTypeStyle(accentColor: Color(hex: "#f43f5e"), bgColor: Color(hex: "#f43f5e").opacity(0.10), systemImage: "heart.fill")
        case .calendarEvent:
            return NodeTypeStyle(accentColor: Color(hex: "#3b82f6"), bgColor: Color(hex: "#3b82f6").opacity(0.10), systemImage: "calendar")
        case .photo:
            return NodeTypeStyle(accentColor: Color(hex: "#a855f7"), bgColor: Color(hex: "#a855f7").opacity(0.10), systemImage: "photo.fill")
        case .reminder:
            return NodeTypeStyle(accentColor: Color(hex: "#22c55e"), bgColor: Color(hex: "#22c55e").opacity(0.10), systemImage: "checklist")
        // ── V2 AI-generated ───────────────────────
        case .aiCluster:
            return NodeTypeStyle(accentColor: Color(hex: "#f97316"), bgColor: Color(hex: "#f97316").opacity(0.10), systemImage: "sparkles")
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
    /// True when the debate agent is actively analyzing this node (shows pulse glow).
    var isDebateEvidence: Bool = false
    /// Accent colors of the node's assigned personas (empty when unassigned).
    var personaColors: [Color] = []

    /// Called when the user selects "삭제" from the context menu.
    var onDelete: () -> Void = {}

    @State private var isHovered   = false
    @State private var pulseScale:  CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.7

    private let style: NodeTypeStyle
    private let cardWidth: CGFloat
    /// True when this is an AI-generated cluster from a multi-agent debate.
    private let isDebateCluster: Bool

    init(node: GraphNode, isSelected: Bool, isConnectionTarget: Bool = false,
         searchOpacity: Double, isDebateEvidence: Bool = false,
         personaColors: [Color] = [],
         onDelete: @escaping () -> Void = {}) {
        self.node = node
        self.isSelected = isSelected
        self.isConnectionTarget = isConnectionTarget
        self.searchOpacity = searchOpacity
        self.isDebateEvidence = isDebateEvidence
        self.personaColors = personaColors
        self.onDelete = onDelete
        self.style = NodeTypeStyle.style(for: node.type)
        self.cardWidth = node.isImportant ? 240 : 210
        self.isDebateCluster = node.type == .aiCluster && node.tags.contains("AI 멀티에이전트")
    }

    var body: some View {
        ZStack {
            // Evidence pulse ring — rendered behind card
            if isDebateEvidence {
                debateEvidenceRing
            }
            // Debate cluster radial glow — rendered behind card
            if isDebateCluster {
                debateClusterGlow
            }
            card
        }
        // Importance badge — top-right corner
        .overlay(alignment: .topTrailing) {
            if node.isImportant || isDebateCluster {
                importanceBadge
            }
        }
        // Persona badge — bottom-left corner (up to 3 dots for multi-persona)
        .overlay(alignment: .bottomLeading) {
            if !personaColors.isEmpty {
                personaBadge(colors: personaColors)
            }
        }
        // Evidence pulse animation lifecycle
        .onAppear {
            guard isDebateEvidence else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulseScale   = 1.12
                pulseOpacity = 0.0
            }
        }
        .onChange(of: isDebateEvidence) { _, active in
            if active {
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    pulseScale = 1.12; pulseOpacity = 0.0
                }
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    pulseScale = 1.0; pulseOpacity = 0.7
                }
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
        .shadow(
            color: isDebateCluster ? Color(hex: "#f97316").opacity(0.45) : .clear,
            radius: isDebateCluster ? 20 : 0
        )
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
                    : isDebateCluster  ? style.accentColor
                    : isSelected       ? style.accentColor
                    :                    style.accentColor.opacity(0.3),
                lineWidth: (isSelected || isConnectionTarget || isDebateCluster) ? 2 : 1
            )
    }

    // ─────────────────────────────────────────────
    // MARK: Debate visual elements
    // ─────────────────────────────────────────────

    /// Expanding pulse ring shown while this node is being analyzed by debate agents.
    private var debateEvidenceRing: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(style.accentColor.opacity(pulseOpacity), lineWidth: 2)
            .scaleEffect(pulseScale)
            .frame(width: cardWidth + 8, height: 130)
            .allowsHitTesting(false)
    }

    /// Static radial orange glow for AI cluster debate result nodes.
    private var debateClusterGlow: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(hex: "#f97316").opacity(0.08))
            .frame(width: cardWidth + 20, height: 140)
            .blur(radius: 12)
            .allowsHitTesting(false)
    }

    // ─────────────────────────────────────────────
    // MARK: Importance badge
    // ─────────────────────────────────────────────

    private var importanceBadge: some View {
        Image(systemName: isDebateCluster ? "brain" : "sparkles")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(isDebateCluster ? Color(hex: "#f97316") : Color(hex: "#f59e0b"))
            .padding(4)
            .background(
                Circle()
                    .fill(.regularMaterial)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            )
            .offset(x: 6, y: -6)
    }

    // ─────────────────────────────────────────────
    // MARK: Persona badge
    // ─────────────────────────────────────────────

    /// Colored dots in the bottom-left corner showing all assigned personas (max 3).
    private func personaBadge(colors: [Color]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(colors.prefix(3).enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.6), radius: 3)
            }
        }
        .padding(8)
        .offset(x: -2, y: 2)
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
