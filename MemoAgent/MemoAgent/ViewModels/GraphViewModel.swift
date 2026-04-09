// GraphViewModel.swift
// MemoAgent — Phase 2: ViewModel
//
// Uses the modern @Observable macro (macOS 14+).
// Owns ALL business logic; zero SwiftUI view code lives here.

import Foundation
import Observation
import CoreGraphics
import FoundationModels

// MARK: - ViewMode

/// Maps the sidebar "View Mode" options from LeftSidebar.tsx.
enum ViewMode: String, CaseIterable, Hashable {
    case context  = "Context View"
    case origin   = "Origin View"
    case timeline = "Timeline View"

    var systemImage: String {
        switch self {
        case .context:  return "square.3.layers.3d"
        case .origin:   return "doc.text"
        case .timeline: return "clock"
        }
    }
}

// MARK: - InputTab

/// Tabs inside the SmartInputModal.
enum InputTab: String, CaseIterable {
    case text = "텍스트 입력"
    case file = "파일 업로드"
}

// MARK: - ProcessStep

/// AI processing pipeline stages shown in the SmartInputModal.
enum ProcessStep: Int {
    case idle       = 0
    case extracting = 1
    case chunking   = 2
    case done       = 3
}

// MARK: - ExtractedNodeData (Generable)

/// AI가 텍스트에서 추출한 하나의 지식 노드 데이터.
/// @Generable 매크로로 FoundationModels의 guided generation을 활성화합니다.
@Generable
struct ExtractedNodeData {
    @Guide(description: "The title of this knowledge node, concise (5–15 words)")
    var title: String

    @Guide(description: "A 1-2 sentence summary of the key insight in this node")
    var summary: String

    @Guide(description: "2-4 relevant keyword tags, no # prefix, comma-separated concepts")
    var tags: String   // comma-separated; split on commit

    @Guide(description: "true if this node contains especially important or insightful content")
    var isImportant: Bool
}

/// A collection of extracted nodes from a single piece of text.
@Generable
struct ExtractedKnowledgeGraph {
    @Guide(description: "List of distinct knowledge nodes extracted from the input text. Extract at most 3 nodes. Aim for 1–3 concise nodes.")
    var nodes: [ExtractedNodeData]
}

// MARK: - Errors

enum ClaudeError: Error, LocalizedError {
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .parseError:
            return "AI 응답 데이터를 JSON으로 파싱하는 데 실패했습니다."
        }
    }
}

// MARK: - GraphViewModel

@Observable
final class GraphViewModel {

    // ─────────────────────────────────────────────
    // MARK: Graph State  (persisted to UserDefaults)
    // ─────────────────────────────────────────────

    private static let nodesKey = "memoagent.nodes.v1"
    private static let edgesKey = "memoagent.edges.v1"

    /// The authoritative list of all nodes on the canvas.
    var nodes: [GraphNode]

    /// The authoritative list of all edges on the canvas.
    var edges: [GraphEdge]

    /// Encode and save nodes + edges to UserDefaults.
    func persistGraph() {
        let enc = JSONEncoder()
        if let nd = try? enc.encode(nodes) {
            UserDefaults.standard.set(nd, forKey: Self.nodesKey)
        }
        if let ed = try? enc.encode(edges) {
            UserDefaults.standard.set(ed, forKey: Self.edgesKey)
        }
    }

    /// Load persisted graph, falling back to sample data if nothing saved yet.
    private static func loadNodes() -> [GraphNode] {
        guard let data = UserDefaults.standard.data(forKey: nodesKey),
              let decoded = try? JSONDecoder().decode([GraphNode].self, from: data),
              !decoded.isEmpty
        else { return sampleNodes }
        return decoded
    }

    private static func loadEdges() -> [GraphEdge] {
        guard let data = UserDefaults.standard.data(forKey: edgesKey),
              let decoded = try? JSONDecoder().decode([GraphEdge].self, from: data)
        else { return sampleEdges }
        return decoded
    }

    init() {
        nodes = Self.loadNodes()
        edges = Self.loadEdges()
    }

    // ─────────────────────────────────────────────
    // MARK: Selection State
    // ─────────────────────────────────────────────

    /// IDs of currently selected nodes.
    /// Multi-select triggers the DetailDrawer's Prompt Composer mode.
    var selectedNodeIDs: Set<String> = []

    /// Convenience accessor for selected `GraphNode` values.
    var selectedNodes: [GraphNode] {
        nodes.filter { selectedNodeIDs.contains($0.id) }
    }

    /// ID of the edge currently hovered by the pointer.
    var hoveredEdgeID: String? = nil

    // ─────────────────────────────────────────────
    // MARK: Edge Connection State
    // ─────────────────────────────────────────────

    /// The node ID from which the user started dragging a new connection.
    var connectingFromNodeID: String? = nil

    /// Current drag endpoint in screen-space (while drawing a pending connection).
    var connectingDragPoint: CGPoint? = nil

    /// The node ID the pending connection is hovering over (highlight target).
    var connectingTargetNodeID: String? = nil

    // ─────────────────────────────────────────────
    // MARK: Viewport / Canvas Transform
    // ─────────────────────────────────────────────

    /// Current zoom scale of the canvas.  Clamped to [minScale, maxScale].
    var canvasScale: CGFloat = 1.0
    let minScale: CGFloat = 0.15
    let maxScale: CGFloat = 2.5

    /// Pan offset of the canvas in screen-space points.
    var canvasOffset: CGSize = .zero

    // Gesture accumulators (not observed by views directly)
    private var baseScale: CGFloat = 1.0
    private var basePanOffset: CGSize = .zero

    // ─────────────────────────────────────────────
    // MARK: Settings State
    // ─────────────────────────────────────────────

    var isSettingsPresented: Bool = false

    // ─────────────────────────────────────────────
    // MARK: Sidebar & Navigation State
    // ─────────────────────────────────────────────

    var isSidebarVisible: Bool = true
    var activeViewMode: ViewMode = .context

    /// Per-type visibility filter.  Nodes whose type is `false` are hidden.
    var typeFilters: [NodeType: Bool] = Dictionary(
        uniqueKeysWithValues: NodeType.allCases.map { ($0, true) }
    )

    // ─────────────────────────────────────────────
    // MARK: Search State
    // ─────────────────────────────────────────────

    var searchQuery: String = ""

    /// Nodes that survive both the type-filter and the search query.
    /// Views use this instead of `nodes` directly.
    var visibleNodes: [GraphNode] {
        nodes.filter { node in
            guard typeFilters[node.type] == true else { return false }
            if searchQuery.isEmpty { return true }
            let q = searchQuery.lowercased()
            return node.title.lowercased().contains(q)
                || node.summary.lowercased().contains(q)
                || node.tags.contains { $0.lowercased().contains(q) }
        }
    }

    /// Edges where BOTH endpoints are in the visible node set.
    /// When search/filter is active, edges connected to hidden nodes are removed.
    var visibleEdges: [GraphEdge] {
        let visibleIDs = Set(visibleNodes.map(\.id))
        return edges.filter {
            visibleIDs.contains($0.sourceID) && visibleIDs.contains($0.targetID)
        }
    }

    /// When a search is active, nodes NOT matching become dimmed.
    func searchOpacity(for node: GraphNode) -> Double {
        guard !searchQuery.isEmpty else { return 1.0 }
        let q = searchQuery.lowercased()
        let matches = node.title.lowercased().contains(q)
            || node.summary.lowercased().contains(q)
            || node.tags.contains { $0.lowercased().contains(q) }
        return matches ? 1.0 : 0.15
    }

    // ─────────────────────────────────────────────
    // MARK: Inspector / Detail Drawer State
    // ─────────────────────────────────────────────

    /// Whether the detail inspector panel is presented.
    /// Only set to true on explicit tap (not during drag).
    var isInspectorPresented: Bool = false

    /// Whether a node drag is currently in progress.
    /// Used to suppress animation and inspector opening during drag.
    var isDraggingNode: Bool = false

    // ─────────────────────────────────────────────
    // MARK: SmartInput Modal State
    // ─────────────────────────────────────────────

    var isAddModalPresented: Bool = false
    var modalInputTab: InputTab = .text
    var modalTitleInput: String = ""
    var modalBodyInput: String = ""
    var modalProcessStep: ProcessStep = .idle

    /// Name of the currently selected upload file (displayed in the drop area).
    var modalUploadFileName: String? = nil
    /// Whether a file has been loaded successfully.
    var modalUploadFileLoaded: Bool = false
    /// AI-analysed nodes ready to commit (filled after .done step).
    var modalAnalysedNodes: [ExtractedNodeData] = []
    /// AI availability error message for the modal.
    var modalAIError: String? = nil

    // ─────────────────────────────────────────────
    // MARK: Prompt Composer State (DetailDrawer)
    // ─────────────────────────────────────────────

    var promptIntent: String = ""
    var generatedPrompt: String = ""

    // ─────────────────────────────────────────────
    // MARK: AI Prompt Generation State
    // ─────────────────────────────────────────────

    /// Whether an on-device AI generation is in progress.
    var isGeneratingAIPrompt: Bool = false
    /// The streaming text from on-device AI (single-node prompt).
    var aiGeneratedPrompt: String = ""
    /// Error message if AI generation failed or is unavailable.
    var aiPromptError: String? = nil

    /// Whether the "connected nodes included" AI analysis is in progress.
    var isGeneratingConnectedPrompt: Bool = false
    /// Streaming result from the connected-nodes analysis.
    var aiConnectedPrompt: String = ""

    // ─────────────────────────────────────────────
    // MARK: Node Drag Tracking
    // ─────────────────────────────────────────────

    /// Tracks each node's position at the start of a drag gesture.
    /// Key = node ID, Value = CGPoint in canvas-space.
    private var dragStartPositions: [String: CGPoint] = [:]

    /// Screen-space translation of the current drag gesture (set by the View).
    /// EdgeLayerView reads this to offset node positions while dragging.
    var liveDragTranslation: CGSize = .zero

    /// IDs of nodes currently being dragged (the drag group).
    var liveDragNodeIDs: Set<String> = []

    // ─────────────────────────────────────────────
    // MARK: - Selection Methods
    // ─────────────────────────────────────────────

    /// Toggle a node's selection state (⌘-click multi-select).
    func toggleSelection(of nodeID: String) {
        if selectedNodeIDs.contains(nodeID) {
            selectedNodeIDs.remove(nodeID)
            if selectedNodeIDs.isEmpty { isInspectorPresented = false }
        } else {
            selectedNodeIDs.insert(nodeID)
            isInspectorPresented = true
        }
        resetPromptComposer()
    }

    /// Select exactly one node, clearing any previous selection.
    /// Pass `openInspector: true` only on tap (not during drag start).
    func selectNode(_ nodeID: String, openInspector: Bool = false) {
        selectedNodeIDs = [nodeID]
        if openInspector { isInspectorPresented = true }
        resetPromptComposer()
    }

    /// Deselect a single node (used by the "×" chip in the DetailDrawer).
    func deselectNode(_ nodeID: String) {
        selectedNodeIDs.remove(nodeID)
        if selectedNodeIDs.isEmpty { isInspectorPresented = false }
        resetPromptComposer()
    }

    /// Clear the entire selection (e.g. clicking empty canvas space).
    func clearSelection() {
        selectedNodeIDs.removeAll()
        isInspectorPresented = false
        resetPromptComposer()
    }

    // ─────────────────────────────────────────────
    // MARK: - Node Manipulation Methods
    // ─────────────────────────────────────────────

    /// Call when a drag gesture begins on a node.
    func beginDrag(nodeID: String) {
        isDraggingNode = true
        liveDragTranslation = .zero
        // Snapshot positions of ALL selected nodes (group-drag support).
        let dragGroup = selectedNodeIDs.contains(nodeID)
            ? selectedNodeIDs
            : [nodeID]
        liveDragNodeIDs = dragGroup
        for id in dragGroup {
            if let node = nodes.first(where: { $0.id == id }) {
                dragStartPositions[id] = node.position
            }
        }
    }

    /// Returns the canvas-space position for a node offset by a drag delta.
    /// Views call this to compute the display position without mutating `nodes`.
    func draggedPosition(nodeID: String, delta: CGSize) -> CGPoint? {
        guard let start = dragStartPositions[nodeID] else { return nil }
        return CGPoint(x: start.x + delta.width, y: start.y + delta.height)
    }

    /// Commits the final drag delta to `nodes` and ends the drag.
    func commitDrag(nodeID: String, delta: CGSize) {
        isDraggingNode = false
        liveDragTranslation = .zero
        liveDragNodeIDs = []
        let dragGroup = selectedNodeIDs.contains(nodeID)
            ? selectedNodeIDs
            : [nodeID]
        for id in dragGroup {
            guard let start = dragStartPositions[id],
                  let idx = nodes.firstIndex(where: { $0.id == id }) else { continue }
            nodes[idx].position = CGPoint(
                x: start.x + delta.width,
                y: start.y + delta.height
            )
            dragStartPositions.removeValue(forKey: id)
        }
        persistGraph()
    }

    // ─────────────────────────────────────────────
    // MARK: - Edge Methods
    // ─────────────────────────────────────────────

    /// Connect selected nodes in sequence (mirrors `connectNodes` imperative handle).
    func connectSelectedNodes() {
        let ids = selectedNodes.map(\.id)
        guard ids.count >= 2 else { return }
        for i in 0..<(ids.count - 1) {
            let src = ids[i], tgt = ids[i + 1]
            let alreadyConnected = edges.contains {
                ($0.sourceID == src && $0.targetID == tgt) ||
                ($0.sourceID == tgt && $0.targetID == src)
            }
            if !alreadyConnected {
                let edge = GraphEdge(
                    id: "e\(src)-\(tgt)-user",
                    sourceID: src,
                    targetID: tgt,
                    style: EdgeStyle(strokeWidth: 2, animated: true, isUserCreated: true)
                )
                edges.append(edge)
            }
        }
        persistGraph()
    }

    /// Remove all edges between any two currently selected nodes.
    func disconnectSelectedNodes() {
        guard selectedNodeIDs.count >= 2 else { return }
        edges.removeAll {
            selectedNodeIDs.contains($0.sourceID) &&
            selectedNodeIDs.contains($0.targetID)
        }
        persistGraph()
    }

    /// Toggle an edge between solid and dashed style.
    func toggleEdgeDash(id: String) {
        guard let idx = edges.firstIndex(where: { $0.id == id }) else { return }
        edges[idx].style.isUserCreated.toggle()
        // When switching to solid, also turn off animation
        if !edges[idx].style.isUserCreated { edges[idx].style.animated = false }
        persistGraph()
    }

    /// Toggle animated marching-ants dash on/off for an edge.
    func toggleEdgeAnimation(id: String) {
        guard let idx = edges.firstIndex(where: { $0.id == id }) else { return }
        edges[idx].style.animated.toggle()
        // Animated implies dashed
        if edges[idx].style.animated { edges[idx].style.isUserCreated = true }
        persistGraph()
    }

    /// Delete a single edge by ID (the "삭제" button on hover).
    func deleteEdge(id: String) {
        edges.removeAll { $0.id == id }
        persistGraph()
    }

    /// Delete a node and all edges connected to it, then deselect it.
    func deleteNode(id: String) {
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.sourceID == id || $0.targetID == id }
        selectedNodeIDs.remove(id)
        if selectedNodeIDs.isEmpty { isInspectorPresented = false }
        persistGraph()
    }

    // ─────────────────────────────────────────────
    // MARK: - Edge Connection Drag
    // ─────────────────────────────────────────────

    /// Begin drawing a new connection starting from `nodeID`.
    func beginConnection(from nodeID: String, at point: CGPoint) {
        connectingFromNodeID   = nodeID
        connectingDragPoint    = point
        connectingTargetNodeID = nil
    }

    /// Update the live drag endpoint and detect hover-target node.
    func updateConnection(to point: CGPoint, canvasSize: CGSize) {
        connectingDragPoint = point
        connectingTargetNodeID = nodes.first { node in
            guard node.id != connectingFromNodeID else { return false }
            let center = self.screenPoint(from: node.position, canvasSize: canvasSize)
            let cardW: CGFloat = (node.isImportant ? 240 : 210) * canvasScale
            let cardH: CGFloat = (node.tags.isEmpty ? 78 : 110) * canvasScale
            let rect = CGRect(x: center.x - cardW / 2, y: center.y - cardH / 2,
                              width: cardW, height: cardH)
            return rect.contains(point)
        }?.id
    }

    /// Finish the connection drag. Creates an edge if dropped on a valid target.
    func finishConnection() {
        defer {
            connectingFromNodeID   = nil
            connectingDragPoint    = nil
            connectingTargetNodeID = nil
        }
        guard let srcID = connectingFromNodeID,
              let tgtID = connectingTargetNodeID,
              srcID != tgtID else { return }

        // Avoid duplicate edges
        let exists = edges.contains {
            ($0.sourceID == srcID && $0.targetID == tgtID) ||
            ($0.sourceID == tgtID && $0.targetID == srcID)
        }
        guard !exists else { return }

        let edge = GraphEdge(
            id: "e\(srcID)-\(tgtID)",
            sourceID: srcID,
            targetID: tgtID,
            style: EdgeStyle(strokeWidth: 1.5, animated: false, isUserCreated: true)
        )
        edges.append(edge)
        persistGraph()
    }

    /// Cancel an in-progress connection drag without creating an edge.
    func cancelConnection() {
        connectingFromNodeID   = nil
        connectingDragPoint    = nil
        connectingTargetNodeID = nil
    }

    // ─────────────────────────────────────────────
    // MARK: - Add Node (SmartInputModal)
    // ─────────────────────────────────────────────

    /// Kick off the real AI processing pipeline.
    /// Routes to Claude API or Apple Intelligence based on the user's provider setting.
    @MainActor
    func startModalAnalysis() {
        guard modalProcessStep == .idle else { return }
        let text = modalBodyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        modalAIError = nil
        modalAnalysedNodes = []
        modalProcessStep = .extracting

        if AIProviderManager.shared.selectedProvider != .appleIntelligence {
            startModalAnalysisWithAPI(text: text)
        } else {
            startModalAnalysisWithAppleIntelligence(text: text)
        }
    }

    // ── External API path (Claude / Google AI / OpenAI) ──────────────

    private func startModalAnalysisWithAPI(text: String) {
        let fallbackTitle = modalTitleInput
        Task {
            do {
                try await Task.sleep(for: .milliseconds(400))
                await MainActor.run { modalProcessStep = .chunking }

                let system = """
                    You are a personal knowledge management assistant. \
                    Extract the core knowledge units from the provided text \
                    and return ONLY valid JSON — no markdown, no explanation. \
                    Respond in the same language as the input text.
                    """
                let userMsg = """
                    Text to analyse:
                    ---
                    \(text.prefix(2000))
                    ---
                    Extract at most 3 distinct knowledge nodes. Return ONLY this JSON structure:
                    {"nodes":[{"title":"concise title 5-15 words","summary":"1-2 sentence summary","tags":"tag1, tag2","isImportant":false}]}
                    """

                let json = try await AIProviderManager.shared.callAI(
                    system: system,
                    userMessage: userMsg,
                    maxTokens: 1500
                )
                let nodes = try Self.parseClaudeNodes(from: json)
                await MainActor.run {
                    modalAnalysedNodes = Array(nodes.prefix(3))
                    modalProcessStep = .done
                }
            } catch {
                await MainActor.run {
                    modalAIError = error.localizedDescription
                    modalAnalysedNodes = [Self.makeFallbackNode(title: fallbackTitle, text: text)]
                    modalProcessStep = .done
                }
            }
        }
    }

    // ── Apple Intelligence path ───────────────────────────────────────

    private func startModalAnalysisWithAppleIntelligence(text: String) {
        let fallbackTitle = modalTitleInput
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            let reason: String
            switch model.availability {
            case .unavailable(.deviceNotEligible):
                reason = "이 기기는 Apple Intelligence를 지원하지 않습니다."
            case .unavailable(.appleIntelligenceNotEnabled):
                reason = "Apple Intelligence가 꺼져 있습니다. 설정에서 활성화해주세요."
            case .unavailable(.modelNotReady):
                reason = "모델을 준비 중입니다. 잠시 후 다시 시도해주세요."
            default:
                reason = "AI 기능을 사용할 수 없습니다."
            }
            modalAIError = reason
            modalAnalysedNodes = [Self.makeFallbackNode(title: fallbackTitle, text: text)]
            modalProcessStep = .done
            return
        }

        Task {
            do {
                let instructions = """
                    You are a personal knowledge management assistant. \
                    Extract the core knowledge units from the provided text \
                    and return them as structured node data. \
                    Respond in the same language as the input text.
                    """
                let session = LanguageModelSession(instructions: instructions)
                let userText = text.prefix(2000).description
                let prompt = """
                    Text to analyse:
                    ---
                    \(userText)
                    ---
                    Extract all distinct knowledge nodes from the text above.
                    """

                try await Task.sleep(for: .milliseconds(400))
                await MainActor.run { modalProcessStep = .chunking }

                let response = try await session.respond(
                    to: prompt,
                    generating: ExtractedKnowledgeGraph.self
                )
                await MainActor.run {
                    modalAnalysedNodes = Array(response.content.nodes.prefix(3))
                    modalProcessStep = .done
                }
            } catch {
                await MainActor.run {
                    modalAIError = error.localizedDescription
                    modalAnalysedNodes = [Self.makeFallbackNode(title: fallbackTitle, text: text)]
                    modalProcessStep = .done
                }
            }
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────

    private static func makeFallbackNode(title: String, text: String) -> ExtractedNodeData {
        ExtractedNodeData(
            title: title.isEmpty ? "새 노드" : title,
            summary: String(text.prefix(120)),
            tags: "",
            isImportant: false
        )
    }

    /// Parses a JSON response from Claude into an array of `ExtractedNodeData`.
    /// Handles optional markdown code fences.
    private static func parseClaudeNodes(from text: String) throws -> [ExtractedNodeData] {
        struct GraphJSON: Decodable {
            struct NodeJSON: Decodable {
                let title: String
                let summary: String
                let tags: String
                let isImportant: Bool
            }
            let nodes: [NodeJSON]
        }

        // Strip markdown code fences if present
        var clean = text
        if let s = text.range(of: "```json"), let e = text.range(of: "```", range: s.upperBound..<text.endIndex) {
            clean = String(text[s.upperBound..<e.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let s = text.range(of: "```"), let e = text.range(of: "```", range: s.upperBound..<text.endIndex) {
            clean = String(text[s.upperBound..<e.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Narrow to outermost { … }
        if let first = clean.firstIndex(of: "{"), let last = clean.lastIndex(of: "}") {
            clean = String(clean[first...last])
        }

        guard let data = clean.data(using: .utf8) else { throw ClaudeError.parseError }
        let graph = try JSONDecoder().decode(GraphJSON.self, from: data)
        return graph.nodes.map { n in
            ExtractedNodeData(title: n.title, summary: n.summary, tags: n.tags, isImportant: n.isImportant)
        }
    }

    /// Commit the AI-extracted nodes to the graph and close the modal.
    func commitModalNodes() {
        guard modalProcessStep == .done else {
            isAddModalPresented = false
            resetModal()
            return
        }

        let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
        let bodyText = modalBodyInput

        // Compute the current viewport centre in canvas-space.
        // screen centre → canvas: x = -canvasOffset.width / canvasScale, y = -canvasOffset.height / canvasScale
        let vcx = -canvasOffset.width  / canvasScale
        let vcy = -canvasOffset.height / canvasScale

        // Spiral layout: place nodes clustered around the viewport centre
        let baseAngle = Double.random(in: 0..<(2 * .pi))
        let radius: CGFloat = 200

        let nodesToAdd: [GraphNode]
        if modalAnalysedNodes.isEmpty {
            // Plain fallback: one node from title+body, placed at viewport centre
            nodesToAdd = [GraphNode(
                id: UUID().uuidString,
                title: modalTitleInput.isEmpty ? "새 노드" : modalTitleInput,
                summary: String(bodyText.prefix(120)),
                type: .memo,
                date: today,
                originalText: bodyText,
                isImportant: false,
                tags: [],
                position: CGPoint(x: vcx, y: vcy)
            )]
        } else {
            nodesToAdd = modalAnalysedNodes.enumerated().map { idx, extracted in
                let count = modalAnalysedNodes.count
                let angle = baseAngle + Double(idx) * (2 * .pi / Double(max(count, 1)))
                // Single node: place exactly at viewport centre; multiple: spread in circle
                let offsetX = count == 1 ? 0 : cos(angle) * radius
                let offsetY = count == 1 ? 0 : sin(angle) * radius

                let tagList = extracted.tags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                return GraphNode(
                    id: UUID().uuidString,
                    title: extracted.title,
                    summary: extracted.summary,
                    type: .memo,
                    date: today,
                    originalText: bodyText,
                    isImportant: extracted.isImportant,
                    tags: tagList,
                    position: CGPoint(x: vcx + offsetX, y: vcy + offsetY)
                )
            }
        }

        // Add nodes and auto-connect them in sequence if more than one
        nodes.append(contentsOf: nodesToAdd)
        if nodesToAdd.count > 1 {
            for i in 0..<(nodesToAdd.count - 1) {
                let edge = GraphEdge(
                    id: "e\(nodesToAdd[i].id)-\(nodesToAdd[i+1].id)",
                    sourceID: nodesToAdd[i].id,
                    targetID: nodesToAdd[i+1].id,
                    style: EdgeStyle(strokeWidth: 1.5, animated: true, isUserCreated: true)
                )
                edges.append(edge)
            }
        }

        persistGraph()
        isAddModalPresented = false
        resetModal()
    }

    func openAddModal() {
        resetModal()
        isAddModalPresented = true
    }

    private func resetModal() {
        modalInputTab = .text
        modalTitleInput = ""
        modalBodyInput = ""
        modalProcessStep = .idle
        modalUploadFileName = nil
        modalUploadFileLoaded = false
    }

    // ─────────────────────────────────────────────
    // MARK: - Prompt Composer (DetailDrawer)
    // ─────────────────────────────────────────────

    /// Assemble a prompt string from the selected nodes and the user's intent.
    /// Mirrors `handleGeneratePrompt` in DetailDrawer.tsx.
    func generatePrompt() {
        let context = selectedNodes
            .map { "- \($0.title): \($0.summary)" }
            .joined(separator: "\n")
        let intent = promptIntent.isEmpty ? "요약" : promptIntent
        let request = promptIntent.isEmpty
            ? "위 내용을 종합하여 핵심 인사이트를 도출해줘."
            : promptIntent
        generatedPrompt = "다음 정보를 바탕으로 \(intent)해줘.\n\n[컨텍스트]\n\(context)\n\n[요청사항]\n\(request)"
    }

    /// Generate a PKM prompt for a single node.
    /// Routes to Claude API or Apple Intelligence based on the user's provider setting.
    @MainActor
    func generateAIPrompt(for node: GraphNode) {
        aiGeneratedPrompt = ""
        aiPromptError = nil

        let instructions = """
            You are a personal knowledge management assistant. \
            Given a knowledge node, write a concise, insightful prompt \
            that helps the user explore, extend, or apply the knowledge. \
            Respond in the same language as the node content. \
            Keep it under 150 words.
            """
        let userPrompt = """
            노드 제목: \(node.title)
            요약: \(node.summary)
            태그: \(node.tags.joined(separator: ", "))
            원본: \(node.originalText.prefix(300))

            위 지식 노드를 바탕으로 탐구·발전시킬 수 있는 프롬프트를 작성해줘.
            """

        if AIProviderManager.shared.selectedProvider != .appleIntelligence {
            isGeneratingAIPrompt = true
            Task {
                defer { isGeneratingAIPrompt = false }
                do {
                    for try await partial in AIProviderManager.shared.streamAI(
                        system: instructions, userMessage: userPrompt, maxTokens: 300
                    ) {
                        aiGeneratedPrompt = partial
                    }
                } catch {
                    aiPromptError = error.localizedDescription
                }
            }
            return
        }

        // Apple Intelligence path
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            isGeneratingAIPrompt = true
            Task {
                defer { isGeneratingAIPrompt = false }
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let stream = session.streamResponse(to: userPrompt)
                    for try await partial in stream {
                        aiGeneratedPrompt = partial.content
                    }
                } catch {
                    aiPromptError = error.localizedDescription
                }
            }
        case .unavailable(.deviceNotEligible):
            aiPromptError = "이 기기는 Apple Intelligence를 지원하지 않습니다."
        case .unavailable(.appleIntelligenceNotEnabled):
            aiPromptError = "Apple Intelligence가 비활성화되어 있습니다. 설정 > Apple Intelligence에서 켜주세요."
        case .unavailable(.modelNotReady):
            aiPromptError = "온디바이스 모델을 준비 중입니다. 잠시 후 다시 시도해주세요."
        case .unavailable:
            aiPromptError = "AI 기능을 사용할 수 없습니다."
        }
    }

    /// Returns all nodes directly connected to `node` (via any edge, either direction).
    func connectedNodes(for node: GraphNode) -> [GraphNode] {
        let connectedIDs = edges.compactMap { edge -> String? in
            if edge.sourceID == node.id { return edge.targetID }
            if edge.targetID == node.id { return edge.sourceID }
            return nil
        }
        return nodes.filter { connectedIDs.contains($0.id) }
    }

    /// Generate an analysis prompt that includes the target node AND its connected neighbours.
    /// Routes to Claude API or Apple Intelligence based on the user's provider setting.
    @MainActor
    func generateConnectedAIPrompt(for node: GraphNode) {
        aiConnectedPrompt = ""

        let neighbours = connectedNodes(for: node)
        let neighbourText = neighbours.isEmpty
            ? "(연결된 노드 없음)"
            : neighbours.map { "  - [\($0.type.rawValue)] \($0.title): \($0.summary)" }.joined(separator: "\n")

        let instructions = """
            You are a personal knowledge management assistant. \
            Given a central knowledge node and its connected neighbour nodes, \
            synthesise the relationships and produce an insightful analysis \
            prompt that explores their connections, contradictions, or synergies. \
            Respond in the same language as the node content. \
            Keep it under 250 words.
            """
        let userPrompt = """
            [중심 노드]
            제목: \(node.title)
            요약: \(node.summary)
            태그: \(node.tags.joined(separator: ", "))
            원본: \(node.originalText.prefix(300))

            [연결된 노드 \(neighbours.count)개]
            \(neighbourText)

            위 중심 노드와 연결된 노드들의 관계를 분석하고, 이를 함께 탐구·발전시킬 수 있는 프롬프트를 작성해줘.
            """

        if AIProviderManager.shared.selectedProvider != .appleIntelligence {
            isGeneratingConnectedPrompt = true
            Task {
                defer { isGeneratingConnectedPrompt = false }
                do {
                    for try await partial in AIProviderManager.shared.streamAI(
                        system: instructions, userMessage: userPrompt, maxTokens: 500
                    ) {
                        aiConnectedPrompt = partial
                    }
                } catch {
                    aiConnectedPrompt = "오류: \(error.localizedDescription)"
                }
            }
            return
        }

        // Apple Intelligence path
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            isGeneratingConnectedPrompt = true
            Task {
                defer { isGeneratingConnectedPrompt = false }
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let stream = session.streamResponse(to: userPrompt)
                    for try await partial in stream {
                        aiConnectedPrompt = partial.content
                    }
                } catch {
                    aiConnectedPrompt = "오류: \(error.localizedDescription)"
                }
            }
        case .unavailable(.deviceNotEligible):
            aiConnectedPrompt = "이 기기는 Apple Intelligence를 지원하지 않습니다."
        case .unavailable(.appleIntelligenceNotEnabled):
            aiConnectedPrompt = "Apple Intelligence가 비활성화되어 있습니다."
        case .unavailable(.modelNotReady):
            aiConnectedPrompt = "온디바이스 모델을 준비 중입니다. 잠시 후 다시 시도해주세요."
        case .unavailable:
            aiConnectedPrompt = "AI 기능을 사용할 수 없습니다."
        }
    }

    private func resetPromptComposer() {
        promptIntent = ""
        generatedPrompt = ""
        aiGeneratedPrompt = ""
        aiConnectedPrompt = ""
        aiPromptError = nil
        isGeneratingAIPrompt = false
        isGeneratingConnectedPrompt = false
    }

    // ─────────────────────────────────────────────
    // MARK: - Viewport / Gesture Methods
    // ─────────────────────────────────────────────

    /// Call at the start of a magnification gesture to snapshot the current scale.
    func beginMagnification() {
        baseScale = canvasScale
    }

    /// Apply a live magnification factor from `MagnifyGesture`.
    /// `magnification` is the raw value from the gesture (1.0 = no change).
    func updateMagnification(_ magnification: CGFloat) {
        canvasScale = (baseScale * magnification).clamped(to: minScale...maxScale)
    }

    /// Call at the start of a pan drag to snapshot the current offset.
    func beginPan() {
        basePanOffset = canvasOffset
    }

    /// Apply a live translation from a canvas `DragGesture`.
    func updatePan(translation: CGSize) {
        canvasOffset = CGSize(
            width:  basePanOffset.width  + translation.width,
            height: basePanOffset.height + translation.height
        )
    }

    // ─────────────────────────────────────────────
    // MARK: - Coordinate Helpers
    // ─────────────────────────────────────────────

    /// Convert a screen-space point to canvas-space, accounting for current
    /// pan offset and zoom scale.  Useful for hit-testing and placing new nodes.
    func canvasPoint(from screenPoint: CGPoint, canvasSize: CGSize) -> CGPoint {
        let cx = canvasSize.width  / 2 + canvasOffset.width
        let cy = canvasSize.height / 2 + canvasOffset.height
        return CGPoint(
            x: (screenPoint.x - cx) / canvasScale,
            y: (screenPoint.y - cy) / canvasScale
        )
    }

    /// Convert a canvas-space node position to the screen-space origin of the
    /// node view, given the current viewport transform.
    func screenPoint(from canvasPoint: CGPoint, canvasSize: CGSize) -> CGPoint {
        let cx = canvasSize.width  / 2 + canvasOffset.width
        let cy = canvasSize.height / 2 + canvasOffset.height
        return CGPoint(
            x: canvasPoint.x * canvasScale + cx,
            y: canvasPoint.y * canvasScale + cy
        )
    }

    // ─────────────────────────────────────────────
    // MARK: - Filter Methods
    // ─────────────────────────────────────────────

    func toggleTypeFilter(_ type: NodeType) {
        typeFilters[type] = !(typeFilters[type] ?? true)
    }
}

// MARK: - Comparable clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
