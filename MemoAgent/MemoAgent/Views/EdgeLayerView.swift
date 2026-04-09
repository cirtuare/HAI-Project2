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

/// Full-size transparent overlay that renders all graph edges (paths only).
/// Placed beneath the node layer inside the canvas ZStack.
/// Action buttons are rendered separately in EdgeInteractionLayer above nodes.
struct EdgeLayerView: View {
    @Environment(GraphViewModel.self) private var vm

    /// Canvas-to-screen transform, provided by GraphCanvasView.
    let canvasSize: CGSize

    var body: some View {
        ZStack {
            // Static Bezier paths drawn on a Canvas for performance
            edgeCanvas
            // Live pending edge while connecting
            if vm.connectingFromNodeID != nil {
                pendingEdgeCanvas
            }
        }
        // Track mouse position across the full canvas to detect edge proximity
        .onContinuousHover { phase in
            guard !vm.isDraggingNode, vm.connectingFromNodeID == nil else {
                vm.hoveredEdgeID = nil
                return
            }
            switch phase {
            case .active(let location):
                vm.hoveredEdgeID = findNearestEdge(at: location)
            case .ended:
                vm.hoveredEdgeID = nil
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Edge Canvas
    // ─────────────────────────────────────────────

    private var edgeCanvas: some View {
        ZStack {
            // Layer 1: solid + dashed (non-animated) edges — redraws instantly on node move
            Canvas { context, _ in
                for edge in vm.visibleEdges {
                    guard !edge.style.animated else { continue }
                    guard let src = vm.nodes.first(where: { $0.id == edge.sourceID }),
                          let tgt = vm.nodes.first(where: { $0.id == edge.targetID })
                    else { continue }

                    let (p0, p3) = bestEndpoints(src: src, tgt: tgt)
                    let path = bezierPath(from: p0, to: p3)
                    let isHovered   = vm.hoveredEdgeID == edge.id
                    let strokeColor = edgeColor(edge: edge, hovered: isHovered)
                    let lineWidth   = edgeLineWidth(edge: edge, hovered: isHovered)

                    if edge.style.isUserCreated {
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round,
                                               dash: [5, 5], dashPhase: 0)
                        )
                    } else {
                        context.stroke(
                            path,
                            with: .color(strokeColor),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }

                    if !edge.relationship.isEmpty {
                        let mid = bezierMidpoint(from: p0, to: p3)
                        let text = context.resolve(Text(edge.relationship).font(.system(size: 10, weight: .bold)))

                        let textSize = text.measure(in: CGSize(width: 100, height: 20))
                        let rect = CGRect(x: mid.x - textSize.width/2 - 4,
                                        y: mid.y - textSize.height/2 - 2,
                                        width: textSize.width + 8, height: textSize.height + 4)

                        context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color(hex: "1e293b")))
                        context.draw(text, at: mid)
                    }
                }
            }

            // Layer 2: animated (marching-ants) edges — TimelineView only when needed
            if vm.visibleEdges.contains(where: { $0.style.animated }) {
                TimelineView(.animation(minimumInterval: 1/30)) { timeline in
                    Canvas { context, _ in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        for edge in vm.visibleEdges where edge.style.animated {
                            guard let src = vm.nodes.first(where: { $0.id == edge.sourceID }),
                                  let tgt = vm.nodes.first(where: { $0.id == edge.targetID })
                            else { continue }

                            let (p0, p3) = bestEndpoints(src: src, tgt: tgt)
                            let path = bezierPath(from: p0, to: p3)
                            let isHovered   = vm.hoveredEdgeID == edge.id
                            let strokeColor = edgeColor(edge: edge, hovered: isHovered)
                            let lineWidth   = edgeLineWidth(edge: edge, hovered: isHovered)
                            let dashLength: CGFloat = 5
                            let gapLength:  CGFloat = 5
                            let phase = CGFloat(t.truncatingRemainder(dividingBy: 1.0)) * (dashLength + gapLength) * -1
                            context.stroke(
                                path,
                                with: .color(strokeColor),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round,
                                                   dash: [dashLength, gapLength], dashPhase: phase)
                            )
                        }
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

            let srcCenter = vm.screenPoint(from: src.position, canvasSize: canvasSize)
            let start = nearestBorderPoint(nodeCenter: srcCenter, node: src,
                                           toward: dragPt)

            let path = bezierPath(from: start, to: dragPt)

            context.stroke(
                path,
                with: .color(Color.cyan.opacity(0.7)),
                style: StrokeStyle(
                    lineWidth: 1.5,
                    lineCap: .round,
                    dash: [5, 5]
                )
            )

            let tipRect = CGRect(x: dragPt.x - 4, y: dragPt.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: tipRect), with: .color(Color.cyan.opacity(0.8)))
        }
        .allowsHitTesting(false)
    }

    // ─────────────────────────────────────────────
    // MARK: Nearest-edge detection via mouse tracking
    // ─────────────────────────────────────────────

    /// Returns the ID of the edge whose bezier curve is within `threshold` pts of `point`.
    private func findNearestEdge(at point: CGPoint) -> String? {
        let threshold: CGFloat = 20
        for edge in vm.visibleEdges {
            guard let src = vm.nodes.first(where: { $0.id == edge.sourceID }),
                  let tgt = vm.nodes.first(where: { $0.id == edge.targetID })
            else { continue }
            let (p0, p3) = bestEndpoints(src: src, tgt: tgt)
            if distanceToBezier(point, p0: p0, p3: p3) < threshold {
                return edge.id
            }
        }
        return nil
    }

    /// Approximates the minimum distance from `point` to the cubic bezier curve
    /// by sampling 40 evenly-spaced points along the curve.
    private func distanceToBezier(_ point: CGPoint, p0: CGPoint, p3: CGPoint) -> CGFloat {
        let dx = p3.x - p0.x
        let dy = p3.y - p0.y
        let dist = max(sqrt(dx*dx + dy*dy), 40)
        let ctrl = min(dist * 0.45, 180.0)
        let absDX = abs(dx), absDY = abs(dy)
        let c1: CGPoint, c2: CGPoint
        if absDY > absDX {
            c1 = CGPoint(x: p0.x, y: p0.y + ctrl * (dy > 0 ? 1 : -1))
            c2 = CGPoint(x: p3.x, y: p3.y - ctrl * (dy > 0 ? 1 : -1))
        } else {
            c1 = CGPoint(x: p0.x + ctrl * (dx > 0 ? 1 : -1), y: p0.y)
            c2 = CGPoint(x: p3.x - ctrl * (dx > 0 ? 1 : -1), y: p3.y)
        }
        var minD = CGFloat.infinity
        for i in 0...40 {
            let t  = CGFloat(i) / 40
            let mt = 1 - t
            let x  = mt*mt*mt*p0.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*p3.x
            let y  = mt*mt*mt*p0.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*p3.y
            let d  = hypot(point.x - x, point.y - y)
            if d < minD { minD = d }
        }
        return minD
    }

    // ─────────────────────────────────────────────
    // MARK: Geometry — nearest-face endpoint selection
    // ─────────────────────────────────────────────

    private func liveCenter(for node: GraphNode) -> CGPoint {
        var pt = vm.screenPoint(from: node.position, canvasSize: canvasSize)
        if vm.liveDragNodeIDs.contains(node.id) {
            pt.x += vm.liveDragTranslation.width
            pt.y += vm.liveDragTranslation.height
        }
        return pt
    }

    private func bestEndpoints(src: GraphNode, tgt: GraphNode) -> (CGPoint, CGPoint) {
        let srcCenter = liveCenter(for: src)
        let tgtCenter = liveCenter(for: tgt)
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
        if abs(dx) < 1 && abs(dy) < 1 { return nodeCenter }
        let tx = (dx == 0) ? CGFloat.infinity : halfW / abs(dx)
        let ty = (dy == 0) ? CGFloat.infinity : halfH / abs(dy)
        let t  = min(tx, ty)
        return CGPoint(x: nodeCenter.x + dx * t,
                       y: nodeCenter.y + dy * t)
    }

    private func bezierPath(from start: CGPoint, to end: CGPoint) -> Path {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = max(sqrt(dx*dx + dy*dy), 40)
        let ctrl = min(dist * 0.45, 180.0)
        let c1: CGPoint, c2: CGPoint
        if abs(dy) > abs(dx) {
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

    // ─────────────────────────────────────────────
    // MARK: Style helpers
    // ─────────────────────────────────────────────

    private func edgeColor(edge: GraphEdge, hovered: Bool) -> Color {
        if hovered                  { return Color(hex: "64748b") }
        if edge.style.isUserCreated { return Color(hex: "38bdf8") }
        // Debate-generated edges get semantic colors
        switch edge.relationship {
        case "근거":      return Color(hex: "f59e0b").opacity(0.55)  // amber — evidence link
        case "실행 항목": return Color(hex: "f97316").opacity(0.85)  // orange — action link
        case "원인":      return Color(hex: "f43f5e").opacity(0.65)  // rose — causal link
        default: break
        }
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

// MARK: - EdgeInteractionLayer

/// Action buttons for edges — rendered above the node layer so buttons are always clickable.
struct EdgeInteractionLayer: View {
    @Environment(GraphViewModel.self) private var vm
    let canvasSize: CGSize

    var body: some View {
        ForEach(vm.visibleEdges) { edge in
            EdgeActionButtons(edge: edge, canvasSize: canvasSize)
        }
    }
}

// MARK: - EdgeActionButtons

/// Shows the floating action panel (관계 설정 / 실선-점선 / 흐름 / 삭제) when this edge is hovered.
/// Visibility is driven by `vm.hoveredEdgeID` — no local hover state needed.
private struct EdgeActionButtons: View {
    @Environment(GraphViewModel.self) private var vm
    let edge: GraphEdge
    let canvasSize: CGSize

    var body: some View {
        let (p0, p3) = edgeEndpoints()
        let midpoint  = bezierMidpoint(from: p0, to: p3)

        ZStack {
            if vm.hoveredEdgeID == edge.id {
                actionPanel(at: midpoint)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.7),
                   value: vm.hoveredEdgeID == edge.id)
    }

    // MARK: Action panel

    private func actionPanel(at point: CGPoint) -> some View {
        HStack(spacing: 2) {
            // ── Edit Relationship ──────────────────
            RelationshipButton(edge: edge)

            Divider().frame(height: 14)

            // ── Solid / Dashed toggle ──────────────
            actionButton(
                icon: "line.diagonal",
                label: edge.style.isUserCreated ? "실선" : "점선",
                active: false
            ) {
                vm.toggleEdgeDash(id: edge.id)
            }

            Divider().frame(height: 14)

            // ── Animation toggle ──────────────────
            actionButton(
                icon: edge.style.animated ? "pause.fill" : "play.fill",
                label: edge.style.animated ? "정지" : "흐름",
                active: edge.style.animated
            ) {
                vm.toggleEdgeAnimation(id: edge.id)
            }

            Divider().frame(height: 14)

            // ── Delete ────────────────────────────
            actionButton(icon: "xmark", label: "삭제", active: false, destructive: true) {
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
        // Bug fix #1: keep panel visible while mouse is over it,
        // even if it strays far from the edge path.
        .onHover { isHovering in
            if isHovering {
                vm.hoveredEdgeID = edge.id
            }
        }
    }

    private func actionButton(icon: String, label: String, active: Bool,
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
                    .fill(active       ? Color.cyan.opacity(0.12)
                          : destructive ? Color(hex: "f43f5e").opacity(0.08)
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Geometry helpers

    private func liveCenter(for node: GraphNode) -> CGPoint {
        var pt = vm.screenPoint(from: node.position, canvasSize: canvasSize)
        if vm.liveDragNodeIDs.contains(node.id) {
            pt.x += vm.liveDragTranslation.width
            pt.y += vm.liveDragTranslation.height
        }
        return pt
    }

    private func edgeEndpoints() -> (CGPoint, CGPoint) {
        guard let src = vm.nodes.first(where: { $0.id == edge.sourceID }),
              let tgt = vm.nodes.first(where: { $0.id == edge.targetID })
        else { return (.zero, .zero) }

        let srcCenter = liveCenter(for: src)
        let tgtCenter = liveCenter(for: tgt)
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
        return CGPoint(x: center.x + dx * min(tx, ty), y: center.y + dy * min(tx, ty))
    }

    private func bezierPath(from start: CGPoint, to end: CGPoint) -> Path {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dist = max(sqrt(dx*dx + dy*dy), 40)
        let ctrl = min(dist * 0.45, 180.0)
        let c1: CGPoint, c2: CGPoint
        if abs(dy) > abs(dx) {
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
}

// MARK: - RelationshipButton

/// A button in the edge action panel that opens the relationship-label editor.
private struct RelationshipButton: View {
    @Environment(GraphViewModel.self) private var vm
    let edge: GraphEdge

    var body: some View {
        Button {
            vm.editingRelationshipEdgeID = edge.id
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 9, weight: .semibold))
                Text(edge.relationship.isEmpty ? "관계 설정" : "수정")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.clear))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RelationshipPopup

/// Centered modal popup for editing an edge's relationship label.
/// Rendered above all other layers so it's never obscured.
struct RelationshipPopup: View {
    @Environment(GraphViewModel.self) private var vm
    let edgeID: String

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap to cancel
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 12) {
                Text("관계 레이블")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                TextField("예: 원인, 결과, 관련됨…", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .focused($focused)
                    .onSubmit { save() }

                HStack {
                    Button("취소") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("저장") { save() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .frame(width: 192)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.09, green: 0.11, blue: 0.15))
                    .shadow(color: .black.opacity(0.6), radius: 24, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
        .onAppear {
            if let edge = vm.edges.first(where: { $0.id == edgeID }) {
                text = edge.relationship
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focused = true
            }
        }
    }

    private func save() {
        vm.updateEdgeRelationship(id: edgeID, newRelationship: text.trimmingCharacters(in: .whitespaces))
        dismiss()
    }

    private func dismiss() {
        vm.editingRelationshipEdgeID = nil
        vm.hoveredEdgeID = nil
    }
}

// MARK: - Shared bezier midpoint helper

private func bezierMidpoint(from p0: CGPoint, to p3: CGPoint) -> CGPoint {
    let dx = p3.x - p0.x
    let dy = p3.y - p0.y
    let dist = max(sqrt(dx*dx + dy*dy), 40)
    let ctrl = min(dist * 0.45, 180.0)
    let p1: CGPoint, p2: CGPoint
    if abs(dy) > abs(dx) {
        p1 = CGPoint(x: p0.x, y: p0.y + ctrl * (dy > 0 ? 1 : -1))
        p2 = CGPoint(x: p3.x, y: p3.y - ctrl * (dy > 0 ? 1 : -1))
    } else {
        p1 = CGPoint(x: p0.x + ctrl * (dx > 0 ? 1 : -1), y: p0.y)
        p2 = CGPoint(x: p3.x - ctrl * (dx > 0 ? 1 : -1), y: p3.y)
    }
    let t: CGFloat = 0.5, mt = 1 - t
    return CGPoint(
        x: mt*mt*mt*p0.x + 3*mt*mt*t*p1.x + 3*mt*t*t*p2.x + t*t*t*p3.x,
        y: mt*mt*mt*p0.y + 3*mt*mt*t*p1.y + 3*mt*t*t*p2.y + t*t*t*p3.y
    )
}
