// EdgeLayerView.swift
// MemoAgent — Phase 4: Edge Rendering + Connection Creation
//
// Draws all edges as smooth cubic Bezier curves on a transparent Canvas.
// Also renders a live "pending" edge while the user drags from a connection handle.
// Endpoint calculation picks the nearest cardinal face of each card (top/bottom/left/right)
// so lines always attach to the card border and never float in mid-air.

import SwiftUI

// MARK: - Constants
 
/// Card dimensions in canvas-space points (unscaled).
private enum CardMetrics {
    static func width(for node: GraphNode) -> CGFloat  { node.isImportant ? 240 : 210 }
    static func height(for node: GraphNode) -> CGFloat { node.tags.isEmpty ? 78  : 110 }
}

// MARK: - EdgeLayerView

/// Full-size transparent overlay that renders all graph edges.
/// Placed beneath the node layer inside the canvas ZStack.
struct EdgeLayerView: View {
    @Environment(GraphViewModel.self) private var vm

    /// Canvas-to-screen transform, provided by GraphCanvasView.
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // Static Bezier paths drawn on a Canvas for performance
            edgeCanvas
            // Interactive delete buttons rendered as SwiftUI views
            edgeDeleteButtons
            // Live pending edge while connecting
            if vm.connectingFromNodeID != nil {
                pendingEdgeCanvas
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Edge Canvas
    // ─────────────────────────────────────────────

    private var edgeCanvas: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { context, _ in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for edge in vm.visibleEdges {
                    guard let src = vm.nodes.first(where: { $0.id == edge.sourceID }),
                          let tgt = vm.nodes.first(where: { $0.id == edge.targetID })
                    else { continue }

                    let (p0, p3) = bestEndpoints(src: src, tgt: tgt)
                    let path = bezierPath(from: p0, to: p3)

                    let isHovered   = vm.hoveredEdgeID == edge.id
                    let strokeColor = edgeColor(edge: edge, hovered: isHovered)
                    let lineWidth   = edgeLineWidth(edge: edge, hovered: isHovered)

                    if edge.style.isUserCreated || edge.style.animated {
                        let dashLength: CGFloat = 5
                        let gapLength:  CGFloat = 5
                        let phase = edge.style.animated
                            ? CGFloat(t.truncatingRemainder(dividingBy: 1.0)) * (dashLength + gapLength) * -1
                            : 0
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(
                                lineWidth: lineWidth,
                                lineCap: .round,
                                dash: [dashLength, gapLength],
                                dashPhase: phase
                            )
                        )
                    } else {
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // ─────────────────────────────────────────────
    // MARK: Pending Edge (while dragging a new connection)
    // ─────────────────────────────────────────────

    private var pendingEdgeCanvas: some View {
        Canvas { context, _ in
            guard let srcID = vm.connectingFromNodeID,
                  let dragPt = vm.connectingDragPoint,
                  let src = vm.nodes.first(where: { $0.id == srcID })
            else { return }

            // Start from the nearest face of the source card toward the drag point
            let srcCenter = vm.screenPoint(from: src.position, canvasSize: canvasSize)
            let start = nearestBorderPoint(nodeCenter: srcCenter, node: src,
                                           toward: dragPt)

            let path = bezierPath(from: start, to: dragPt)

            // Dashed cyan line while dragging
            context.stroke(
                path,
                with: .color(Color.cyan.opacity(0.7)),
                style: StrokeStyle(
                    lineWidth: 1.5,
                    lineCap: .round,
                    dash: [5, 5]
                )
            )

            // Small circle at drag tip
            let tipRect = CGRect(x: dragPt.x - 4, y: dragPt.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: tipRect), with: .color(Color.cyan.opacity(0.8)))
        }
        .allowsHitTesting(false)
    }

    // ─────────────────────────────────────────────
    // MARK: Invisible hit-test overlays + delete buttons
    // ─────────────────────────────────────────────

    private var edgeDeleteButtons: some View {
        ForEach(vm.visibleEdges) { edge in
            EdgeInteractionOverlay(edge: edge, canvasSize: canvasSize)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Geometry — nearest-face endpoint selection
    // ─────────────────────────────────────────────

    /// Chooses the best pair of connection points on each card border
    /// so the line always exits from the face nearest the other node.
    private func bestEndpoints(src: GraphNode, tgt: GraphNode) -> (CGPoint, CGPoint) {
        let srcCenter = vm.screenPoint(from: src.position, canvasSize: canvasSize)
        let tgtCenter = vm.screenPoint(from: tgt.position, canvasSize: canvasSize)
        let s = vm.canvasScale

        let srcW = CardMetrics.width(for: src)  * s
        let srcH = CardMetrics.height(for: src) * s
        let tgtW = CardMetrics.width(for: tgt)  * s
        let tgtH = CardMetrics.height(for: tgt) * s

        let p0 = nearestBorderPoint(nodeCenter: srcCenter,
                                    halfW: srcW / 2, halfH: srcH / 2,
                                    toward: tgtCenter)
        let p3 = nearestBorderPoint(nodeCenter: tgtCenter,
                                    halfW: tgtW / 2, halfH: tgtH / 2,
                                    toward: srcCenter)
        return (p0, p3)
    }

    /// Returns the point on the card border closest to `target`.
    /// Picks among the four cardinal face centres (top/bottom/left/right)
    /// and returns the one whose face direction most closely aligns with the
    /// vector from `nodeCenter` to `target`.
    private func nearestBorderPoint(nodeCenter: CGPoint, node: GraphNode,
                                    toward target: CGPoint) -> CGPoint {
        let s = vm.canvasScale
        let hw = CardMetrics.width(for: node)  * s / 2
        let hh = CardMetrics.height(for: node) * s / 2
        return nearestBorderPoint(nodeCenter: nodeCenter, halfW: hw, halfH: hh, toward: target)
    }

    private func nearestBorderPoint(nodeCenter: CGPoint,
                                    halfW: CGFloat, halfH: CGFloat,
                                    toward target: CGPoint) -> CGPoint {
        let dx = target.x - nodeCenter.x
        let dy = target.y - nodeCenter.y

        // Clamp to card border using the aspect-ratio of the direction vector
        if abs(dx) < 1 && abs(dy) < 1 { return nodeCenter }

        let tx = (dx == 0) ? .infinity : halfW / abs(dx)
        let ty = (dy == 0) ? .infinity : halfH / abs(dy)
        let t  = min(tx, ty)

        return CGPoint(x: nodeCenter.x + dx * t,
                       y: nodeCenter.y + dy * t)
    }

    /// Cubic Bezier with control points tangent to the exit direction.
    private func bezierPath(from start: CGPoint, to end: CGPoint) -> Path {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = max(sqrt(dx*dx + dy*dy), 40)
        // Control point distance scales with chord length (capped)
        let ctrl = min(dist * 0.45, 180.0)

        // Determine dominant axis at each end by looking at direction
        let c1: CGPoint
        let c2: CGPoint

        let absDX = abs(dx)
        let absDY = abs(dy)

        if absDY > absDX {
            // Mostly vertical — curve vertically
            c1 = CGPoint(x: start.x, y: start.y + ctrl * (dy > 0 ? 1 : -1))
            c2 = CGPoint(x: end.x,   y: end.y   - ctrl * (dy > 0 ? 1 : -1))
        } else {
            // Mostly horizontal — curve horizontally
            c1 = CGPoint(x: start.x + ctrl * (dx > 0 ? 1 : -1), y: start.y)
            c2 = CGPoint(x: end.x   - ctrl * (dx > 0 ? 1 : -1), y: end.y)
        }

        return Path { p in
            p.move(to: start)
            p.addCurve(to: end, control1: c1, control2: c2)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Style helpers
    // ─────────────────────────────────────────────

    private func edgeColor(edge: GraphEdge, hovered: Bool) -> Color {
        if hovered                  { return Color(hex: "64748b") }  // slate-500
        if edge.style.isUserCreated { return Color(hex: "38bdf8") }  // sky-400 (user edges in cyan)
        switch Int(edge.style.strokeWidth) {
        case 3:  return Color(hex: "64748b")
        case 1:  return Color(hex: "334155")
        default: return Color(hex: "475569")
        }
    }

    private func edgeLineWidth(edge: GraphEdge, hovered: Bool) -> CGFloat {
        hovered ? edge.style.strokeWidth + 1 : edge.style.strokeWidth
    }
}

// MARK: - EdgeInteractionOverlay

/// Renders an invisible wide stroke over the edge for hit-testing,
/// plus the floating "삭제" delete button on hover.
private struct EdgeInteractionOverlay: View {
    @Environment(GraphViewModel.self) private var vm
    let edge: GraphEdge
    let canvasSize: CGSize

    @State private var isHovered = false

    var body: some View {
        GeometryReader { _ in
            let (p0, p3) = edgeEndpoints()
            let midpoint  = bezierMidpoint(from: p0, to: p3)
            let path      = bezierPath(from: p0, to: p3)

            ZStack {
                // Wide transparent stroke for easy hover/click
                path
                    .stroke(Color.clear, lineWidth: 20)
                    .contentShape(path.stroke(lineWidth: 20))
                    .onHover { hovering in
                        isHovered = hovering
                        vm.hoveredEdgeID = hovering ? edge.id : nil
                    }

                // Delete button
                if isHovered {
                    deleteButton(at: midpoint)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isHovered)
        }
    }

    private func deleteButton(at point: CGPoint) -> some View {
        HStack(spacing: 2) {
            // ── Solid / Dashed toggle ──────────────
            edgeStyleButton(
                icon: edge.style.isUserCreated ? "line.diagonal" : "line.diagonal",
                label: edge.style.isUserCreated ? "실선" : "점선",
                active: false
            ) {
                vm.toggleEdgeDash(id: edge.id)
            }

            Divider().frame(height: 14)

            // ── Animation toggle ──────────────────
            edgeStyleButton(
                icon: edge.style.animated ? "pause.fill" : "play.fill",
                label: edge.style.animated ? "정지" : "흐름",
                active: edge.style.animated
            ) {
                vm.toggleEdgeAnimation(id: edge.id)
            }

            Divider().frame(height: 14)

            // ── Delete ────────────────────────────
            edgeStyleButton(icon: "xmark", label: "삭제", active: false, destructive: true) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                    vm.deleteEdge(id: edge.id)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.1, green: 0.12, blue: 0.16).opacity(0.96))
                .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .position(point)
        .onHover { h in
            isHovered = h
            vm.hoveredEdgeID = h ? edge.id : nil
        }
    }

    private func edgeStyleButton(icon: String, label: String, active: Bool,
                                 destructive: Bool = false,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(
                destructive ? Color(hex: "f43f5e")
                    : active    ? Color.cyan
                    :             Color.white.opacity(0.6)
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(active ? Color.cyan.opacity(0.12)
                              : destructive ? Color(hex: "f43f5e").opacity(0.08)
                              : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            isHovered = h
            vm.hoveredEdgeID = h ? edge.id : nil
        }
    }

    // MARK: Geometry helpers

    private func edgeEndpoints() -> (CGPoint, CGPoint) {
        guard let src = vm.nodes.first(where: { $0.id == edge.sourceID }),
              let tgt = vm.nodes.first(where: { $0.id == edge.targetID })
        else { return (.zero, .zero) }

        let srcCenter = vm.screenPoint(from: src.position, canvasSize: canvasSize)
        let tgtCenter = vm.screenPoint(from: tgt.position, canvasSize: canvasSize)
        let s = vm.canvasScale

        let srcHW = CardMetrics.width(for: src)  * s / 2
        let srcHH = CardMetrics.height(for: src) * s / 2
        let tgtHW = CardMetrics.width(for: tgt)  * s / 2
        let tgtHH = CardMetrics.height(for: tgt) * s / 2

        let p0 = borderPoint(center: srcCenter, halfW: srcHW, halfH: srcHH, toward: tgtCenter)
        let p3 = borderPoint(center: tgtCenter, halfW: tgtHW, halfH: tgtHH, toward: srcCenter)
        return (p0, p3)
    }

    private func borderPoint(center: CGPoint, halfW: CGFloat, halfH: CGFloat,
                              toward target: CGPoint) -> CGPoint {
        let dx = target.x - center.x
        let dy = target.y - center.y
        if abs(dx) < 1 && abs(dy) < 1 { return center }
        let tx = (dx == 0) ? CGFloat.infinity : halfW / abs(dx)
        let ty = (dy == 0) ? CGFloat.infinity : halfH / abs(dy)
        let t  = min(tx, ty)
        return CGPoint(x: center.x + dx * t, y: center.y + dy * t)
    }

    private func bezierPath(from start: CGPoint, to end: CGPoint) -> Path {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = max(sqrt(dx*dx + dy*dy), 40)
        let ctrl = min(dist * 0.45, 180.0)
        let absDX = abs(dx)
        let absDY = abs(dy)
        let c1: CGPoint
        let c2: CGPoint
        if absDY > absDX {
            c1 = CGPoint(x: start.x, y: start.y + ctrl * (dy > 0 ? 1 : -1))
            c2 = CGPoint(x: end.x,   y: end.y   - ctrl * (dy > 0 ? 1 : -1))
        } else {
            c1 = CGPoint(x: start.x + ctrl * (dx > 0 ? 1 : -1), y: start.y)
            c2 = CGPoint(x: end.x   - ctrl * (dx > 0 ? 1 : -1), y: end.y)
        }
        return Path { p in
            p.move(to: start)
            p.addCurve(to: end, control1: c1, control2: c2)
        }
    }

    private func bezierMidpoint(from p0: CGPoint, to p3: CGPoint) -> CGPoint {
        let dx = p3.x - p0.x
        let dy = p3.y - p0.y
        let dist = max(sqrt(dx*dx + dy*dy), 40)
        let ctrl = min(dist * 0.45, 180.0)
        let absDX = abs(dx)
        let absDY = abs(dy)
        let p1: CGPoint
        let p2: CGPoint
        if absDY > absDX {
            p1 = CGPoint(x: p0.x, y: p0.y + ctrl * (dy > 0 ? 1 : -1))
            p2 = CGPoint(x: p3.x, y: p3.y - ctrl * (dy > 0 ? 1 : -1))
        } else {
            p1 = CGPoint(x: p0.x + ctrl * (dx > 0 ? 1 : -1), y: p0.y)
            p2 = CGPoint(x: p3.x - ctrl * (dx > 0 ? 1 : -1), y: p3.y)
        }
        let t: CGFloat = 0.5
        let mt = 1 - t
        return CGPoint(
            x: mt*mt*mt*p0.x + 3*mt*mt*t*p1.x + 3*mt*t*t*p2.x + t*t*t*p3.x,
            y: mt*mt*mt*p0.y + 3*mt*mt*t*p1.y + 3*mt*t*t*p2.y + t*t*t*p3.y
        )
    }
}
