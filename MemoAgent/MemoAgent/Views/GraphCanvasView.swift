// GraphCanvasView.swift
// MemoAgent — Phase 4: Full Interactive Graph Canvas

import SwiftUI

struct GraphCanvasView: View {
    @Environment(GraphViewModel.self) private var vm

    // Which node is currently being moved
    @State private var draggingNodeID: String? = nil
    // Live drag translation in screen-space (converted to canvas-space for display)
    @State private var dragTranslation: CGSize = .zero
    // Did the current gesture travel far enough to count as a drag (not a tap)?
    @State private var didDrag = false
    // Which node started a connection drag
    @State private var connectingNodeID: String? = nil

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color(hex: "#020617").ignoresSafeArea()

                DotGridView(canvasOffset: vm.canvasOffset, canvasScale: vm.canvasScale)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                EdgeLayerView(canvasSize: size)
                    .allowsHitTesting(true)

                nodeLayer(canvasSize: size)

                // Edge action buttons rendered above node layer (zIndex > node max of 10)
                if !vm.isDraggingNode {
                    EdgeInteractionLayer(canvasSize: size)
                        .zIndex(20)
                }

                // Relationship editor as a centered popup above all layers
                if let editID = vm.editingRelationshipEdgeID {
                    RelationshipPopup(edgeID: editID)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: editID)
                        .zIndex(100)
                }

                FloatingActionsView()
            }
            .gesture(canvasPanGesture)
            .gesture(magnifyGesture)
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    vm.clearSelection()
                    vm.cancelConnection()
                    vm.hoveredEdgeID = nil
                    vm.editingRelationshipEdgeID = nil
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Node Layer
    // ─────────────────────────────────────────────

    private func nodeLayer(canvasSize: CGSize) -> some View {
        ForEach(vm.visibleNodes) { node in
            // During drag, offset position locally without mutating vm.nodes
            let isDraggingThis = draggingNodeID == node.id ||
                (vm.selectedNodeIDs.contains(node.id) && draggingNodeID != nil && vm.selectedNodeIDs.contains(draggingNodeID ?? ""))
            let basePos = vm.screenPoint(from: node.position, canvasSize: canvasSize)
            let screenPos: CGPoint = isDraggingThis
                ? CGPoint(
                    x: basePos.x + dragTranslation.width,
                    y: basePos.y + dragTranslation.height
                  )
                : basePos
            let isSelected = vm.selectedNodeIDs.contains(node.id)
            let isTarget   = vm.connectingTargetNodeID == node.id

            ZStack {
                NodeCardView(
                    node: node,
                    isSelected: isSelected,
                    isConnectionTarget: isTarget,
                    searchOpacity: vm.searchOpacity(for: node),
                    onDelete: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            vm.deleteNode(id: node.id)
                        }
                    }
                )

                ConnectionHandle(nodeID: node.id, screenPos: screenPos, canvasSize: canvasSize)
            }
            .scaleEffect(vm.canvasScale)
            .position(screenPos)
            .gesture(nodeOptionDragGesture(nodeID: node.id, canvasSize: canvasSize))
            .gesture(nodeMoveDragGesture(nodeID: node.id, canvasSize: canvasSize))
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        guard !didDrag else { return }
                        if vm.connectingFromNodeID != nil {
                            vm.connectingTargetNodeID = node.id
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                vm.finishConnection()
                            }
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                vm.selectNode(node.id, openInspector: true)
                            }
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .modifiers(.command)
                    .onEnded {
                        guard !didDrag else { return }
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            vm.toggleSelection(of: node.id)
                        }
                    }
            )
            .zIndex(isSelected ? 10 : (isTarget ? 9 : 1))
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Gestures
    // ─────────────────────────────────────────────

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if draggingNodeID == nil && connectingNodeID == nil {
                    vm.updatePan(translation: value.translation)
                }
            }
            .onEnded { _ in
                vm.beginPan()
            }
    }

    /// ⌥-drag on a node → draw a new edge connection.
    private func nodeOptionDragGesture(nodeID: String, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .modifiers(.option)
            .onChanged { value in
                if connectingNodeID == nil {
                    connectingNodeID = nodeID
                    vm.beginConnection(from: nodeID, at: value.location)
                }
                guard connectingNodeID == nodeID else { return }
                vm.updateConnection(to: value.location, canvasSize: canvasSize)
            }
            .onEnded { _ in
                vm.finishConnection()
                connectingNodeID = nil
            }
    }

    /// Plain drag on a node → move it. Tracks `didDrag` to suppress accidental tap selection.
    private func nodeMoveDragGesture(nodeID: String, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if !didDrag {
                    didDrag = true
                    draggingNodeID = nodeID
                    dragTranslation = .zero
                    if !vm.selectedNodeIDs.contains(nodeID) {
                        vm.selectNode(nodeID)
                    }
                    vm.beginDrag(nodeID: nodeID)
                }
                guard draggingNodeID == nodeID else { return }
                // Store raw screen-space translation; screenPos offset applied in nodeLayer
                dragTranslation = value.translation
                vm.liveDragTranslation = value.translation
            }
            .onEnded { value in
                guard draggingNodeID == nodeID else { return }
                // Commit final canvas-space delta to vm only once at drag end
                let canvasDelta = CGSize(
                    width:  value.translation.width  / vm.canvasScale,
                    height: value.translation.height / vm.canvasScale
                )
                vm.commitDrag(nodeID: nodeID, delta: canvasDelta)
                draggingNodeID = nil
                dragTranslation = .zero
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    didDrag = false
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in vm.updateMagnification(value.magnification) }
            .onEnded   { value in
                vm.updateMagnification(value.magnification)
                vm.beginMagnification()
            }
    }
}

// MARK: - ConnectionHandle

/// Circular handle on the right edge of each card. Drag it to create a new edge.
private struct ConnectionHandle: View {
    @Environment(GraphViewModel.self) private var vm
    let nodeID: String
    let screenPos: CGPoint
    let canvasSize: CGSize

    @State private var isHovered  = false
    @State private var isDragging = false

    var body: some View {
        let isActive = isHovered || isDragging || vm.connectingFromNodeID == nodeID

        Circle()
            .fill(isActive ? Color.cyan : Color.clear)
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(isActive ? Color.cyan : Color.white.opacity(0.3), lineWidth: 1.5))
            .shadow(color: isActive ? Color.cyan.opacity(0.5) : .clear, radius: 6)
            // Offset to right-center of card (unscaled — parent applies .scaleEffect)
            .offset(x: 118, y: 0)
            .opacity(isActive || vm.connectingFromNodeID != nil ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: isActive)
            .onHover { isHovered = $0 }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            vm.beginConnection(from: nodeID, at: value.location)
                        }
                        vm.updateConnection(to: value.location, canvasSize: canvasSize)
                    }
                    .onEnded { _ in
                        isDragging = false
                        vm.finishConnection()
                    }
            )
    }
}

// MARK: - DotGridView

struct DotGridView: View {
    let canvasOffset: CGSize
    let canvasScale: CGFloat

    var body: some View {
        Canvas { context, size in
            let gap    = 24.0 * canvasScale
            let radius = 1.5  * canvasScale
            let color  = Color(hex: "#1e293b")

            let ox = canvasOffset.width.truncatingRemainder(dividingBy: gap)
            let oy = canvasOffset.height.truncatingRemainder(dividingBy: gap)

            let cols = Int(size.width  / gap) + 2
            let rows = Int(size.height / gap) + 2

            for col in 0...cols {
                for row in 0...rows {
                    let x = CGFloat(col) * gap + ox - gap
                    let y = CGFloat(row) * gap + oy - gap
                    let rect = CGRect(x: x - radius, y: y - radius,
                                      width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}

#Preview {
    GraphCanvasView()
        .environment(GraphViewModel())
        .frame(width: 1100, height: 700)
}
