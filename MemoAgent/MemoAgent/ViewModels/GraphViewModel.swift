// GraphViewModel.swift
// MemoAgent — Phase 2: ViewModel
//
// Uses the modern @Observable macro (macOS 14+).
// Owns ALL business logic; zero SwiftUI view code lives here.

import Foundation
import Observation
import CoreGraphics
import FoundationModels
import SwiftData

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
    case text       = "텍스트 입력"
    case file       = "파일 업로드"
    case screenTime = "스크린타임"
    case finance    = "지출 내역"
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
    @Guide(description: "The name of the entity itself — a person, object, place, or concept (1–4 words). NOT a descriptive phrase. Examples: '홍길동', 'Pikachu', 'Harvard University', '포켓몬스터'")
    var title: String

    @Guide(description: "A 1-2 sentence description of who or what this entity is, based on the input text")
    var summary: String

    @Guide(description: "2-4 relevant keyword tags, no # prefix, comma-separated")
    var tags: String   // comma-separated; split on commit

    @Guide(description: "true if this entity is especially central or important in the text")
    var isImportant: Bool
}

/// A collection of extracted nodes from a single piece of text.
@Generable
struct ExtractedKnowledgeGraph {
    @Guide(description: "List of distinct entities (people, objects, places, concepts) found in the input. Each entity becomes one node. Extract at most 3. Do NOT create nodes for relationships or descriptions — only for the subjects themselves.")
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
    // MARK: SwiftData Backing Store
    // ─────────────────────────────────────────────

    private let modelContext: ModelContext

    // ─────────────────────────────────────────────
    // MARK: Graph State
    // ─────────────────────────────────────────────

    /// The authoritative in-memory list of nodes (view layer).
    var nodes: [GraphNode]

    /// The authoritative in-memory list of edges (view layer).
    var edges: [GraphEdge]

    // ─────────────────────────────────────────────
    // MARK: V2 — Persona & Sync State
    // ─────────────────────────────────────────────

    var personas: [PersonaRecord] = []
    var activePersona: PersonaRecord? = nil
    var showingPersonaOnboarding: Bool = false
    var isSyncing: Bool = false
    var lastSyncDate: Date? = nil

    // ─────────────────────────────────────────────
    // MARK: V2 — Persona Router State
    // ─────────────────────────────────────────────

    /// Personas suggested by PersonaRouter for the current chat query.
    var suggestedPersonas: [PersonaType] = []
    /// Persona type that NodeManagerAgent recommends creating (node threshold exceeded).
    var pendingPersonaSuggestion: PersonaType? = nil

    // ─────────────────────────────────────────────
    // MARK: V2 — Multi-Persona Chat State
    // ─────────────────────────────────────────────

    /// Whether the multi-persona chat sheet is open.
    var isChatPresented: Bool = false
    /// Current active chat session (multi-persona).
    var activeChatSession: ChatSession? = nil
    /// Messages in the current chat session (in-memory mirror for the view).
    var chatMessages: [ChatMessage] = []
    /// IDs of the individual personas the user has selected for the current chat session.
    var chatSelectedPersonaIDs: Set<String> = []
    /// True while waiting for persona AI responses.
    var isChatLoading: Bool = false
    /// Error string shown in the chat UI.
    var chatError: String? = nil

    // ── Single-Persona (1:1) Chat ─────────────────
    var isSingleChatPresented: Bool = false
    var singleChatPersonaType: PersonaType? = nil
    var singleChatSession: ChatSession? = nil
    var singleChatMessages: [ChatMessage] = []
    var isSingleChatLoading: Bool = false

    // ─────────────────────────────────────────────
    // MARK: V2 — Multi-Agent Debate State
    // ─────────────────────────────────────────────

    /// Non-nil while a debate is running; shown as a status banner.
    var debateStatus: String? = nil
    /// The most recent synthesis result from a completed debate (raw JSON string).
    var activeDebateResult: String? = nil
    /// Node IDs currently being analyzed by the debate agents (shown with pulse glow).
    var debateEvidenceNodeIDs: Set<String> = []
    /// All AgentTurns from the current/most-recent debate (streamed in real time).
    var liveDebateTurns: [AgentTurn] = []
    /// Whether the live debate visualization sheet is open.
    var isLiveDebatePresented: Bool = false
    /// Full transcript of the most recently completed debate.
    var activeDebateTranscript: [AgentTurn] = []

    // MARK: - Persistence (SwiftData)

    /// Full sync: reconcile in-memory structs with SwiftData, then save.
    func persistGraph() {
        // ── Nodes ──────────────────────────────────────────────────
        let existingNodes = (try? modelContext.fetch(FetchDescriptor<NodeRecord>())) ?? []
        let existingNodeMap = Dictionary(uniqueKeysWithValues: existingNodes.map { ($0.id, $0) })
        let liveNodeIDs = Set(nodes.map { $0.id })

        for record in existingNodes where !liveNodeIDs.contains(record.id) {
            modelContext.delete(record)
        }
        for node in nodes {
            if let record = existingNodeMap[node.id] {
                record.update(from: node)
            } else {
                modelContext.insert(NodeRecord.from(node))
            }
        }

        // ── Edges ──────────────────────────────────────────────────
        let existingEdges = (try? modelContext.fetch(FetchDescriptor<EdgeRecord>())) ?? []
        let existingEdgeMap = Dictionary(uniqueKeysWithValues: existingEdges.map { ($0.id, $0) })
        let liveEdgeIDs = Set(edges.map { $0.id })

        for record in existingEdges where !liveEdgeIDs.contains(record.id) {
            modelContext.delete(record)
        }
        for edge in edges {
            if let record = existingEdgeMap[edge.id] {
                record.update(from: edge)
            } else {
                modelContext.insert(EdgeRecord.from(edge))
            }
        }

        try? modelContext.save()
    }

    /// Kick off cross-domain pattern detection and debate if warranted.
    /// Must be called on the main actor (uses internal modelContext).
    @MainActor
    func runDebatePatternDetection() {
        let ctx = modelContext
        Task {
            await NodeManagerAgent.shared.runPatternDetection(context: ctx, viewModel: self)
        }
    }

    /// Manually trigger a multi-agent debate for the given persona types and user query.
    /// Opens LiveDebateView immediately; results populate activeDebateResult when done.
    @MainActor
    func triggerManualDebate(personaTypes: [PersonaType], query: String) {
        liveDebateTurns = []
        isLiveDebatePresented = true
        let ctx = modelContext
        Task {
            await DebateOrchestrator.shared.startManualDebate(
                personaTypes: personaTypes,
                query: query,
                context: ctx,
                viewModel: self
            )
        }
    }

    /// Re-fetch nodes/edges from SwiftData and refresh in-memory arrays.
    /// Called after background sync agents insert new records.
    @MainActor
    func refreshFromSwiftData() {
        let fetched = (try? modelContext.fetch(FetchDescriptor<NodeRecord>())) ?? []
        nodes = fetched.map { $0.toGraphNode() }
        let fetchedEdges = (try? modelContext.fetch(FetchDescriptor<EdgeRecord>())) ?? []
        edges = fetchedEdges.map { $0.toGraphEdge() }
        personas = (try? modelContext.fetch(FetchDescriptor<PersonaRecord>())) ?? []
        activePersona = personas.first(where: { $0.isActive })
    }

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // One-time migration from UserDefaults V1
        MigrationService.migrateIfNeeded(context: modelContext)

        // Load from SwiftData
        let fetched = (try? modelContext.fetch(FetchDescriptor<NodeRecord>())) ?? []
        if fetched.isEmpty {
            // First launch — seed with sample data and persist
            nodes = sampleNodes
            edges = sampleEdges
        } else {
            nodes = fetched.map { $0.toGraphNode() }
            let fetchedEdges = (try? modelContext.fetch(FetchDescriptor<EdgeRecord>())) ?? []
            edges = fetchedEdges.map { $0.toGraphEdge() }
        }

        // Load personas
        let loadedPersonas = (try? modelContext.fetch(FetchDescriptor<PersonaRecord>())) ?? []
        personas = loadedPersonas
        activePersona = loadedPersonas.first(where: { $0.isActive })
        showingPersonaOnboarding = loadedPersonas.isEmpty

        // Persist sample data if just seeded
        if fetched.isEmpty {
            // Persist on next runloop tick to avoid init-time re-entrancy
            DispatchQueue.main.async { [weak self] in self?.persistGraph() }
        }
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

    /// ID of the edge whose relationship label is currently being edited.
    var editingRelationshipEdgeID: String? = nil

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

    /// Per-type visibility filter. Nodes whose type is `false` are hidden.
    var typeFilters: [NodeType: Bool] = Dictionary(
        uniqueKeysWithValues: NodeType.allCases.map { ($0, true) }
    )

    // ─────────────────────────────────────────────
    // MARK: Search State
    // ─────────────────────────────────────────────

    var searchQuery: String = ""

    /// Nodes that survive persona filter, type-filter, and search query.
    /// Views use this instead of `nodes` directly.
    var visibleNodes: [GraphNode] {
        nodes.filter { node in
            // Persona filter: show node only if (1) no active persona,
            // or (2) node is explicitly assigned to the active persona.
            if let persona = activePersona {
                guard node.personaIDs.contains(persona.id) else { return false }
            }
            // Type filter
            guard typeFilters[node.type] == true else { return false }
            // Search filter
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

    // ── Screen Time tab state ──────────────────────────────────────────
    var modalScreenTimeInput: String = ""
    var modalScreenTimeSaving: Bool = false
    var modalScreenTimeSavedCount: Int = 0

    // ── Finance tab state ──────────────────────────────────────────────
    var modalFinanceInput: String = ""
    var modalFinanceSaving: Bool = false
    var modalFinanceSavedCount: Int = 0

    // ── Persona override (all tabs) ─────────────────────────────────────
    /// Persona manually selected by the user in the modal. Overrides auto-detect.
    var modalSelectedPersonaID: String? = nil

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
                let edgeID = "e\(src)-\(tgt)-user"
                let edge = GraphEdge(
                    id: edgeID,
                    sourceID: src,
                    targetID: tgt,
                    relationship: "",
                    style: EdgeStyle(strokeWidth: 2, animated: true, isUserCreated: true)
                )
                edges.append(edge)
                generateEdgeRelationship(edgeID: edgeID)
            }
        }
        persistGraph()
    }

    // ─────────────────────────────────────────────
    // MARK: - Auto-link & Edge Relationship (Task 13 & 14)
    // ─────────────────────────────────────────────

    /// Links each new node to up to 2 existing nodes that share the most tags.
    /// Uses the first shared tag as a heuristic relationship label.
    /// Resolves the persona IDs to assign to a newly created node.
    /// - `""` (explicit "없음") → empty array
    /// - specific ID → that persona
    /// - `nil` ("자동 배정") → keyword-routes `text` to best-matching persona type;
    ///   falls back to active persona then first available
    private func resolvePersonaIDs(for text: String) -> [String] {
        if modalSelectedPersonaID == "" { return [] }
        if let specific = modalSelectedPersonaID { return [specific] }
        let matched = PersonaRouter.shared.keywordRoute(query: text).first
        let id = matched.flatMap { type in personas.first(where: { $0.personaType == type }) }?.id
            ?? activePersona?.id
            ?? personas.first?.id
        return id.map { [$0] } ?? []
    }

    private func autoLinkToExisting(newNodes: [GraphNode], existingNodes: [GraphNode]) {
        for newNode in newNodes {
            guard !newNode.tags.isEmpty else { continue }
            let newTagSet = Set(newNode.tags.map { $0.lowercased() })

            let candidates = existingNodes
                .compactMap { existing -> (GraphNode, Set<String>)? in
                    guard !existing.tags.isEmpty else { return nil }
                    let overlap = Set(existing.tags.map { $0.lowercased() }).intersection(newTagSet)
                    return overlap.isEmpty ? nil : (existing, overlap)
                }
                .sorted { $0.1.count > $1.1.count }
                .prefix(2)

            for (existing, sharedTags) in candidates {
                let alreadyConnected = edges.contains {
                    ($0.sourceID == newNode.id && $0.targetID == existing.id) ||
                    ($0.sourceID == existing.id && $0.targetID == newNode.id)
                }
                guard !alreadyConnected else { continue }
                let label = "#\(sharedTags.sorted().first ?? "관련")"
                let edgeID = "e\(newNode.id)-\(existing.id)-auto"
                edges.append(GraphEdge(
                    id: edgeID,
                    sourceID: newNode.id,
                    targetID: existing.id,
                    relationship: label,
                    style: EdgeStyle(strokeWidth: 1, animated: false, isUserCreated: false)
                ))
                generateEdgeRelationship(edgeID: edgeID)
            }
        }
    }

    /// Asynchronously generates a concise relationship label for a user-created edge
    /// via the active AI provider, then updates the edge in-place.
    private func generateEdgeRelationship(edgeID: String) {
        guard AIProviderManager.shared.selectedProvider != .appleIntelligence else { return }
        guard let edgeIdx = edges.firstIndex(where: { $0.id == edgeID }),
              let src = nodes.first(where: { $0.id == edges[edgeIdx].sourceID }),
              let tgt = nodes.first(where: { $0.id == edges[edgeIdx].targetID }) else { return }

        let srcTitle = src.title
        let srcSummary = String(src.summary.prefix(60))
        let tgtTitle = tgt.title
        let tgtSummary = String(tgt.summary.prefix(60))

        Task {
            let userMsg = """
                소스 노드: "\(srcTitle)" — \(srcSummary)
                대상 노드: "\(tgtTitle)" — \(tgtSummary)

                두 노드 사이의 관계를 2~4개 한국어 단어로 간결하게 표현하세요.
                예시: "원인-결과", "보완 관계", "실습 vs 이론", "연장선"
                관계 표현만 출력하세요. 다른 텍스트는 포함하지 마세요.
                """
            guard let raw = try? await AIProviderManager.shared.callAI(
                system: PromptStore.shared.prompt(for: .edgeRelationship),
                userMessage: userMsg, maxTokens: 20
            ) else { return }
            let label = raw
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .components(separatedBy: "\n").first ?? ""
            guard !label.isEmpty else { return }
            await MainActor.run {
                if let idx = self.edges.firstIndex(where: { $0.id == edgeID }) {
                    self.edges[idx].relationship = label
                    self.persistGraph()
                }
            }
        }
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

    /// Delete all currently selected nodes and their edges.
    func deleteSelectedNodes() {
        let ids = selectedNodeIDs
        nodes.removeAll { ids.contains($0.id) }
        edges.removeAll { ids.contains($0.sourceID) || ids.contains($0.targetID) }
        selectedNodeIDs.removeAll()
        isInspectorPresented = false
        persistGraph()
    }

    /// Replace the persona assignment for all currently selected nodes.
    func assignPersonaToSelected(_ personaID: String?) {
        for idx in nodes.indices where selectedNodeIDs.contains(nodes[idx].id) {
            var updated = nodes[idx]
            updated.personaIDs = [personaID].compactMap { $0 }
            nodes[idx] = updated
        }
        persistGraph()
    }

    /// Assign (or remove) a persona from a node. Pass nil to make it globally visible.
    /// Replace the full persona assignment list for a node (single-assignment path, used by inspector menu).
    func assignPersona(_ personaID: String?, to nodeID: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        var updated = nodes[idx]
        updated.personaIDs = [personaID].compactMap { $0 }
        nodes[idx] = updated   // explicit replacement — triggers @Observable setter
        persistGraph()
    }

    /// Add a persona to a node's assignment list (multi-persona path).
    func addPersona(_ personaID: String, to nodeID: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == nodeID }),
              !nodes[idx].personaIDs.contains(personaID) else { return }
        var updated = nodes[idx]
        updated.personaIDs.append(personaID)
        nodes[idx] = updated   // explicit replacement — triggers @Observable setter
        persistGraph()
    }

    /// Remove a persona from a node's assignment list.
    func removePersona(_ personaID: String, from nodeID: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        var updated = nodes[idx]
        updated.personaIDs.removeAll { $0 == personaID }
        nodes[idx] = updated   // explicit replacement — triggers @Observable setter
        persistGraph()
    }

    func updateEdgeRelationship(id: String, newRelationship: String) {
        guard let idx = edges.firstIndex(where: { $0.id == id }) else { return }
        edges[idx].relationship = newRelationship
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

        let edgeID = "e\(srcID)-\(tgtID)"
        let edge = GraphEdge(
            id: edgeID,
            sourceID: srcID,
            targetID: tgtID,
            relationship: "",
            style: EdgeStyle(strokeWidth: 1.5, animated: false, isUserCreated: true)
        )
        edges.append(edge)
        persistGraph()
        generateEdgeRelationship(edgeID: edgeID)
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

                let system = PromptStore.shared.prompt(for: .nodeExtractionAPI)
                let userMsg = """
                    Extract the distinct entities (people, objects, places, or key concepts) from the text below as individual knowledge nodes. Each node title must be the entity name itself — NOT a descriptive phrase.

                    EXAMPLE INPUT:
                    홍길동은 내 대학 동기이다. 홍길동은 다른 대학 동기인 김영희와 애인 관계이다. 홍길동은 포켓몬스터를 좋아한다.

                    EXAMPLE OUTPUT:
                    {"nodes":[
                      {"title":"홍길동","summary":"내 대학 동기. 김영희와 애인 관계이며 포켓몬스터를 좋아함.","tags":"인간관계, 대학","isImportant":true},
                      {"title":"김영희","summary":"홍길동의 대학 동기이자 애인.","tags":"인간관계, 대학","isImportant":false},
                      {"title":"포켓몬스터","summary":"홍길동이 좋아하는 취미.","tags":"취미, 게임","isImportant":false}
                    ]}

                    TEXT TO ANALYSE:
                    ---
                    \(text.prefix(2000))
                    ---
                    Return ONLY valid JSON in the exact same structure as the example above. At most 3 nodes.
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
                let session = LanguageModelSession(instructions: PromptStore.shared.prompt(for: .nodeExtractionApple))
                let userText = text.prefix(2000).description
                let prompt = """
                    Extract the distinct entities (people, objects, places, key concepts) from the text below. Each entity becomes one node. The node title must be the entity name itself — NOT a description or phrase.

                    Example — Input: "홍길동은 내 대학 동기이다. 김영희와 애인 관계이며 포켓몬스터를 좋아한다."
                    Example — Nodes: ["홍길동", "김영희", "포켓몬스터"]

                    Text to analyse:
                    ---
                    \(userText)
                    ---
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

        // Spread new nodes in a circle of radius 220 around viewport centre
        let baseAngle = Double.random(in: 0..<(2 * .pi))
        let radius: CGFloat = 220

        // Collect existing node positions to avoid overlap
        var occupiedPositions = nodes.map(\.position)

        let nodesToAdd: [GraphNode]
        if modalAnalysedNodes.isEmpty {
            let pos = nonOverlappingPosition(
                near: CGPoint(x: vcx, y: vcy),
                occupied: occupiedPositions
            )
            occupiedPositions.append(pos)
            nodesToAdd = [GraphNode(
                id: UUID().uuidString,
                title: modalTitleInput.isEmpty ? "새 노드" : modalTitleInput,
                summary: String(bodyText.prefix(120)),
                type: .memo,
                date: today,
                originalText: bodyText,
                isImportant: false,
                tags: [],
                position: pos,
                personaIDs: resolvePersonaIDs(for: "\(modalTitleInput) \(bodyText)")
            )]
        } else {
            var result: [GraphNode] = []
            for (idx, extracted) in modalAnalysedNodes.enumerated() {
                let count = modalAnalysedNodes.count
                let angle = baseAngle + Double(idx) * (2 * .pi / Double(max(count, 1)))
                let offsetX = count == 1 ? 0 : cos(angle) * radius
                let offsetY = count == 1 ? 0 : sin(angle) * radius
                let candidate = CGPoint(x: vcx + offsetX, y: vcy + offsetY)
                let pos = nonOverlappingPosition(near: candidate, occupied: occupiedPositions)
                occupiedPositions.append(pos)

                let tagList = extracted.tags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                result.append(GraphNode(
                    id: UUID().uuidString,
                    title: extracted.title,
                    summary: extracted.summary,
                    type: .memo,
                    date: today,
                    originalText: bodyText,
                    isImportant: extracted.isImportant,
                    tags: tagList,
                    position: pos,
                    personaIDs: resolvePersonaIDs(for: "\(extracted.title) \(extracted.summary) \(extracted.tags)")
                ))
            }
            nodesToAdd = result
        }

        // ── Task 25: Deduplicate against existing nodes ──────────────────────
        // For each candidate whose title matches an existing node, merge its
        // content into the existing node (Task 24) instead of creating a duplicate.
        var idRemap: [String: String] = [:]   // candidateID → existingID
        var trulyNewNodes: [GraphNode] = []

        for candidate in nodesToAdd {
            let key = candidate.title.lowercased().trimmingCharacters(in: .whitespaces)
            if let existingIdx = nodes.firstIndex(where: {
                $0.title.lowercased().trimmingCharacters(in: .whitespaces) == key
            }) {
                idRemap[candidate.id] = nodes[existingIdx].id
                // Task 24: append new summary / tags to existing node
                var merged = nodes[existingIdx]
                if !candidate.summary.isEmpty && !merged.summary.contains(candidate.summary) {
                    merged.summary += "\n" + candidate.summary
                }
                let addTags = candidate.tags.filter { !merged.tags.contains($0) }
                merged.tags += addTags
                nodes[existingIdx] = merged
            } else {
                trulyNewNodes.append(candidate)
            }
        }

        // Helper: resolve a node ID through the dedup remap table
        func effectiveID(_ id: String) -> String { idRemap[id] ?? id }

        // Capture snapshot BEFORE inserting truly new nodes
        let existingSnapshot = nodes

        // Add only nodes that don't already exist
        nodes.append(contentsOf: trulyNewNodes)

        // Connect the full original sequence using remapped IDs where applicable
        if nodesToAdd.count > 1 {
            for i in 0..<(nodesToAdd.count - 1) {
                let srcID = effectiveID(nodesToAdd[i].id)
                let tgtID = effectiveID(nodesToAdd[i + 1].id)
                guard srcID != tgtID else { continue }
                let alreadyConnected = edges.contains {
                    ($0.sourceID == srcID && $0.targetID == tgtID) ||
                    ($0.sourceID == tgtID && $0.targetID == srcID)
                }
                guard !alreadyConnected else { continue }
                let edgeID = "e\(srcID)-\(tgtID)"
                let edge = GraphEdge(
                    id: edgeID,
                    sourceID: srcID,
                    targetID: tgtID,
                    relationship: "관련",
                    style: EdgeStyle(strokeWidth: 1.5, animated: true, isUserCreated: true)
                )
                edges.append(edge)
                generateEdgeRelationship(edgeID: edgeID)
            }
        }

        // Auto-link truly new nodes to related existing nodes by tag overlap
        autoLinkToExisting(newNodes: trulyNewNodes, existingNodes: existingSnapshot)

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
        modalScreenTimeInput = ""
        modalScreenTimeSaving = false
        modalScreenTimeSavedCount = 0
        modalFinanceInput = ""
        modalFinanceSaving = false
        modalFinanceSavedCount = 0
        modalSelectedPersonaID = nil
    }

    // ── Screen Time commit ─────────────────────────────────────────────

    @MainActor
    func commitScreenTimeReport() {
        let text = modalScreenTimeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !modalScreenTimeSaving else { return }

        // Manual override takes priority; fall back to auto-detect (health) or active persona
        let targetPersona: PersonaRecord?
        if let overrideID = modalSelectedPersonaID {
            targetPersona = personas.first(where: { $0.id == overrideID })
        } else {
            targetPersona = personas.first(where: { $0.personaType == .health }) ?? activePersona
        }

        guard let persona = targetPersona else {
            // No persona available — still save as unattached nodes
            commitScreenTimeReportUnattached(text: text)
            return
        }

        modalScreenTimeSaving = true
        Task {
            await EcosystemSyncService.shared.syncScreenTime(
                reportText: text,
                persona: persona,
                viewModel: self,
                context: modelContext
            )
            await MainActor.run {
                // Count how many nodes were inserted (approximate via modalScreenTimeSavedCount)
                modalScreenTimeSavedCount = 1  // summary node always created
                modalScreenTimeSaving = false
            }
        }
    }

    @MainActor
    private func commitScreenTimeReportUnattached(text: String) {
        // Fallback: parse and create a placeholder persona-less node
        modalScreenTimeSaving = true
        Task {
            let (total, categories) = await ScreenTimeSyncProvider.shared.parse(text)
            let placeholder = PersonaRecord(
                name: "건강",
                personaTypeRaw: PersonaType.health.rawValue,
                systemPromptContext: PersonaType.health.systemPromptContext,
                accentColorHex: PersonaType.health.accentHex
            )
            let nodes = await ScreenTimeSyncProvider.shared.createNodes(
                reportText: text,
                total: total,
                categories: categories,
                persona: placeholder
            )
            await MainActor.run {
                insertEcosystemNodes(nodes)
                modalScreenTimeSavedCount = nodes.count
                modalScreenTimeSaving = false
            }
        }
    }

    // ── Finance commit ─────────────────────────────────────────────────

    @MainActor
    func commitFinanceStatement() {
        let text = modalFinanceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !modalFinanceSaving else { return }

        // Manual override takes priority; fall back to auto-detect (finance) or active persona
        let targetPersona: PersonaRecord?
        if let overrideID = modalSelectedPersonaID {
            targetPersona = personas.first(where: { $0.id == overrideID })
        } else {
            targetPersona = personas.first(where: { $0.personaType == .finance }) ?? activePersona
        }

        guard let persona = targetPersona else {
            commitFinanceStatementUnattached(text: text)
            return
        }

        modalFinanceSaving = true
        Task {
            let count = await EcosystemSyncService.shared.syncFinance(
                statementText: text,
                source: .text,
                persona: persona,
                viewModel: self,
                context: modelContext
            )
            await MainActor.run {
                modalFinanceSavedCount = count
                modalFinanceSaving = false
            }
        }
    }

    @MainActor
    private func commitFinanceStatementUnattached(text: String) {
        modalFinanceSaving = true
        Task {
            let entries = await FinanceSyncProvider.shared.parse(text, source: .text)
            let placeholder = PersonaRecord(
                name: "금융",
                personaTypeRaw: PersonaType.finance.rawValue,
                systemPromptContext: PersonaType.finance.systemPromptContext,
                accentColorHex: PersonaType.finance.accentHex
            )
            let nodes = await FinanceSyncProvider.shared.createNodes(
                entries: entries,
                rawText: text,
                persona: placeholder
            )
            for entry in entries { modelContext.insert(entry) }
            try? modelContext.save()
            await MainActor.run {
                insertEcosystemNodes(nodes)
                modalFinanceSavedCount = entries.count
                modalFinanceSaving = false
            }
        }
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

        let instructions = PromptStore.shared.prompt(for: .singleNodePrompt)
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

        let instructions = PromptStore.shared.prompt(for: .connectedNodePrompt)
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
    // MARK: - Node Placement Helpers
    // ─────────────────────────────────────────────

    /// Returns a canvas-space position near `candidate` that doesn't overlap any node in `occupied`.
    /// Spirals outward in expanding rings until a free slot is found (max 60 attempts).
    private func nonOverlappingPosition(
        near candidate: CGPoint,
        occupied: [CGPoint],
        minDistance: CGFloat = 260
    ) -> CGPoint {
        guard !occupied.isEmpty else { return candidate }

        func isFree(_ pt: CGPoint) -> Bool {
            occupied.allSatisfy { other in
                let dx = pt.x - other.x, dy = pt.y - other.y
                return (dx * dx + dy * dy) >= (minDistance * minDistance)
            }
        }

        if isFree(candidate) { return candidate }

        let step: CGFloat = minDistance
        for ring in 1...12 {
            let r = step * CGFloat(ring)
            let slices = max(8, ring * 6)
            for s in 0..<slices {
                let angle = (2 * CGFloat.pi / CGFloat(slices)) * CGFloat(s)
                let pt = CGPoint(x: candidate.x + cos(angle) * r,
                                 y: candidate.y + sin(angle) * r)
                if isFree(pt) { return pt }
            }
        }
        return candidate
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

    // ─────────────────────────────────────────────
    // MARK: - V2 Persona Management
    // ─────────────────────────────────────────────

    /// Insert a new PersonaRecord into SwiftData and refresh the persona list.
    func createPersona(_ record: PersonaRecord) {
        modelContext.insert(record)
        try? modelContext.save()
        personas = (try? modelContext.fetch(FetchDescriptor<PersonaRecord>())) ?? []
    }

    /// Delete a persona. Nodes assigned to it lose that persona (remaining assignments preserved).
    func deletePersona(id: String) {
        // Unassign nodes before deleting — explicit replacement triggers @Observable setter
        for idx in nodes.indices where nodes[idx].personaIDs.contains(id) {
            var updated = nodes[idx]
            updated.personaIDs.removeAll { $0 == id }
            nodes[idx] = updated
        }
        persistGraph()

        guard let record = personas.first(where: { $0.id == id }) else { return }
        if activePersona?.id == id { clearPersona() }
        modelContext.delete(record)
        try? modelContext.save()
        personas = (try? modelContext.fetch(FetchDescriptor<PersonaRecord>())) ?? []
    }

    /// Rename a persona.
    func updatePersonaName(id: String, name: String) {
        guard let record = personas.first(where: { $0.id == id }),
              !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        record.name = name.trimmingCharacters(in: .whitespaces)
        try? modelContext.save()
        personas = (try? modelContext.fetch(FetchDescriptor<PersonaRecord>())) ?? []
    }

    /// Select a persona and deactivate all others.
    func activatePersona(_ persona: PersonaRecord) {
        for p in personas { p.isActive = false }
        persona.isActive = true
        activePersona = persona
        try? modelContext.save()
        AIProviderManager.shared.activePersonaContext = persona.systemPromptContext
    }

    /// Deactivate all personas (show all nodes).
    func clearPersona() {
        for p in personas { p.isActive = false }
        activePersona = nil
        try? modelContext.save()
        AIProviderManager.shared.activePersonaContext = nil
    }

    /// Save selected personas from onboarding and activate the first one.
    func finishOnboarding(selected types: [PersonaType]) {
        guard !types.isEmpty else { return }
        for (i, type) in types.enumerated() {
            let record = PersonaRecord.make(from: type, isActive: i == 0)
            modelContext.insert(record)
        }
        try? modelContext.save()
        personas = (try? modelContext.fetch(FetchDescriptor<PersonaRecord>())) ?? []
        activePersona = personas.first(where: { $0.isActive })
        if let active = activePersona {
            AIProviderManager.shared.activePersonaContext = active.systemPromptContext
        }
        showingPersonaOnboarding = false
    }

    // ─────────────────────────────────────────────
    // MARK: - V2 Ecosystem Node Insertion
    // ─────────────────────────────────────────────

    /// Insert nodes from ecosystem sync directly into SwiftData and in-memory array.
    /// Called by EcosystemSyncService after importing Apple framework data.
    @MainActor
    func insertEcosystemNodes(_ newNodes: [GraphNode]) {
        guard !newNodes.isEmpty else { return }
        let existingExternalIDs = Set(nodes.compactMap { $0.externalID })
        let deduplicated = newNodes.filter { node in
            guard let extID = node.externalID else { return true }
            return !existingExternalIDs.contains(extID)
        }
        for node in deduplicated {
            nodes.append(node)
            modelContext.insert(NodeRecord.from(node))
        }
        try? modelContext.save()
        lastSyncDate = Date()
    }

    // ─────────────────────────────────────────────
    // MARK: - Multi-Persona Chat
    // ─────────────────────────────────────────────

    /// Open the chat sheet and route the initial query if non-empty.
    @MainActor
    func openChat(initialQuery: String = "") {
        chatError = nil
        isChatPresented = true
        guard !initialQuery.isEmpty else { return }
        // Pre-populate persona suggestions using keyword fallback (sync, no await needed)
        let suggested = PersonaRouter.shared.keywordRoute(query: initialQuery)
        let autoSelected = personas.filter { p in
            p.personaType.map { suggested.contains($0) } ?? false
        }
        chatSelectedPersonaIDs = Set(autoSelected.map { $0.id })
        suggestedPersonas = suggested.filter { t in personas.contains { $0.personaType == t } }
    }

    /// Create a new ChatSession, send the user's query, then collect one response
    /// per selected persona in parallel.
    @MainActor
    func startChatSession(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isChatLoading else { return }

        let selectedPersonas = personas.filter { chatSelectedPersonaIDs.contains($0.id) }
        let selectedTypes = Array(Set(selectedPersonas.compactMap { $0.personaType }))
        guard !selectedTypes.isEmpty else {
            chatError = "최소 한 개의 페르소나를 선택하세요."
            return
        }

        chatError = nil
        isChatLoading = true

        // Create a new session
        let session = ChatSession(
            title: String(trimmed.prefix(40)),
            selectedPersonaTypeRaws: selectedTypes.map { $0.rawValue }
        )
        modelContext.insert(session)

        // User message
        let userMsg = ChatMessage(role: ChatRole.user, content: trimmed)
        userMsg.session = session
        modelContext.insert(userMsg)

        activeChatSession = session
        chatMessages = [userMsg]

        try? modelContext.save()

        Task {
            await generatePersonaResponses(
                query: trimmed,
                session: session,
                personaTypes: selectedTypes
            )
        }
    }

    /// Send a follow-up message to an existing session.
    @MainActor
    func sendChatMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isChatLoading,
              let session = activeChatSession else { return }

        chatError = nil
        isChatLoading = true

        let userMsg = ChatMessage(role: ChatRole.user, content: trimmed)
        userMsg.session = session
        modelContext.insert(userMsg)
        chatMessages.append(userMsg)
        try? modelContext.save()

        let selectedTypes = session.selectedPersonaTypes
        Task {
            await generatePersonaResponses(
                query: trimmed,
                session: session,
                personaTypes: selectedTypes
            )
        }
    }

    /// Sendable DTO carrying persona response content across concurrency boundaries.
    /// Using a DTO avoids passing non-Sendable @Model objects between tasks.
    private struct PersonaResponseDTO: Sendable {
        let personaTypeRaw: String
        let content: String
    }

    private func generatePersonaResponses(
        query: String,
        session: ChatSession,
        personaTypes: [PersonaType]
    ) async {
        // Extract only the Sendable string we need from MainActor — never pass ChatMessage across boundary
        let historyText = await MainActor.run {
            chatMessages.suffix(6).map { msg -> String in
                let prefix = msg.role == ChatRole.user ? "사용자" :
                             (msg.personaType?.localizedName ?? "시스템")
                return "[\(prefix)] \(msg.content)"
            }.joined(separator: "\n")
        }

        let order = personaTypes.map { $0.rawValue }

        // Round 1: each persona responds independently in parallel
        let round1: [PersonaResponseDTO] = await withTaskGroup(of: PersonaResponseDTO?.self) { group in
            for pType in personaTypes {
                group.addTask {
                    await self.generateResponse(for: pType, query: query, history: historyText)
                }
            }
            var results: [PersonaResponseDTO] = []
            for await dto in group {
                if let dto { results.append(dto) }
            }
            return results
        }

        // Persist Round 1 messages on the main actor
        await MainActor.run {
            let sorted = round1.sorted {
                (order.firstIndex(of: $0.personaTypeRaw) ?? 99) <
                (order.firstIndex(of: $1.personaTypeRaw) ?? 99)
            }
            for dto in sorted {
                let msg = ChatMessage(
                    role: ChatRole.persona,
                    personaTypeRaw: dto.personaTypeRaw,
                    content: dto.content
                )
                msg.session = session
                modelContext.insert(msg)
                chatMessages.append(msg)
            }
            try? modelContext.save()
        }

        // Round 2: each persona cross-responds to the other personas' Round 1 answers
        // Only meaningful when 2+ personas are participating
        if personaTypes.count >= 2 {
            let round2: [PersonaResponseDTO] = await withTaskGroup(of: PersonaResponseDTO?.self) { group in
                for pType in personaTypes {
                    let othersContext = round1
                        .filter { $0.personaTypeRaw != pType.rawValue }
                        .compactMap { dto -> String? in
                            guard let otherType = PersonaType(rawValue: dto.personaTypeRaw) else { return nil }
                            return "[\(otherType.localizedName)] \(dto.content)"
                        }
                        .joined(separator: "\n\n")
                    guard !othersContext.isEmpty else { continue }
                    group.addTask {
                        await self.generateCrossResponse(for: pType, query: query, othersContext: othersContext)
                    }
                }
                var results: [PersonaResponseDTO] = []
                for await dto in group {
                    if let dto { results.append(dto) }
                }
                return results
            }

            await MainActor.run {
                let sorted = round2.sorted {
                    (order.firstIndex(of: $0.personaTypeRaw) ?? 99) <
                    (order.firstIndex(of: $1.personaTypeRaw) ?? 99)
                }
                for dto in sorted {
                    let msg = ChatMessage(
                        role: ChatRole.persona,
                        personaTypeRaw: dto.personaTypeRaw,
                        content: dto.content
                    )
                    msg.session = session
                    modelContext.insert(msg)
                    chatMessages.append(msg)
                }
                isChatLoading = false
                try? modelContext.save()
            }
        } else {
            await MainActor.run {
                isChatLoading = false
                try? modelContext.save()
            }
        }
    }

    private func generateCrossResponse(
        for personaType: PersonaType,
        query: String,
        othersContext: String
    ) async -> PersonaResponseDTO? {
        let nodeContext = await MainActor.run { buildNodeContext(for: personaType) }
        let crossSuffix = PromptStore.shared.prompt(for: .personaCrossResponse,
                                                     replacing: "personaName",
                                                     with: personaType.localizedName)
        let systemPrompt = """
            \(personaType.systemPromptContext)

            \(crossSuffix)\(nodeContext.isEmpty ? "" : "\n\n[관련 데이터]\n\(nodeContext)")
            """
        let userMessage = """
            [원래 질문] \(query)

            [다른 관점들의 의견]
            \(othersContext)
            """
        do {
            let content = try await AIProviderManager.shared.callAI(
                system: systemPrompt,
                userMessage: userMessage,
                maxTokens: 300
            )
            return PersonaResponseDTO(personaTypeRaw: personaType.rawValue, content: content)
        } catch {
            return nil  // silently skip cross-response on error
        }
    }

    private func generateResponse(
        for personaType: PersonaType,
        query: String,
        history: String
    ) async -> PersonaResponseDTO? {
        // Collect relevant node context for this persona
        let nodeContext = await MainActor.run { buildNodeContext(for: personaType) }

        let chatSuffix = PromptStore.shared.prompt(for: .personaChatSuffix,
                                                    replacing: "personaName",
                                                    with: personaType.localizedName)
        let systemPrompt = """
            \(personaType.systemPromptContext)

            \(chatSuffix)\(nodeContext.isEmpty ? "" : "\n\n[관련 데이터]\n\(nodeContext)")
            """

        let userMessage = history.isEmpty
            ? query
            : "\(history)\n\n[새 메시지] \(query)"

        do {
            let content = try await AIProviderManager.shared.callAI(
                system: systemPrompt,
                userMessage: userMessage,
                maxTokens: 400
            )
            return PersonaResponseDTO(personaTypeRaw: personaType.rawValue, content: content)
        } catch {
            return PersonaResponseDTO(
                personaTypeRaw: personaType.rawValue,
                content: "응답 생성에 실패했습니다: \(error.localizedDescription)"
            )
        }
    }

    /// Build a brief summary of the most recent nodes relevant to a persona type.
    @MainActor
    private func buildNodeContext(for personaType: PersonaType) -> String {
        let relevantSourceRaws: [String]
        switch personaType {
        case .health:   relevantSourceRaws = [SourceSystem.healthKit.rawValue,
                                               SourceSystem.screenTime.rawValue]
        case .finance:  relevantSourceRaws = [SourceSystem.finance.rawValue]
        case .hobby:    relevantSourceRaws = [SourceSystem.photos.rawValue]
        case .academic: relevantSourceRaws = [SourceSystem.calendar.rawValue,
                                               SourceSystem.reminders.rawValue]
        case .other:    relevantSourceRaws = []
        }

        // Find persona record to match by personaID too
        let personaIDs = personas
            .filter { $0.personaType == personaType }
            .map { $0.id }

        let relevant = nodes.filter { node in
            let bySource = relevantSourceRaws.contains(node.sourceSystem.rawValue)
            let byPersona = node.personaIDs.contains(where: { personaIDs.contains($0) })
            return bySource || byPersona
        }
        .sorted { $0.date > $1.date }
        .prefix(5)

        guard !relevant.isEmpty else { return "" }
        return relevant
            .map { "- \($0.title): \($0.summary)" }
            .joined(separator: "\n")
    }

    /// Close the chat sheet and reset state.
    @MainActor
    func closeChat() {
        isChatPresented = false
        activeChatSession = nil
        chatMessages = []
        chatSelectedPersonaIDs = []
        suggestedPersonas = []
        chatError = nil
        isChatLoading = false
    }

    // ─────────────────────────────────────────────
    // MARK: - Single-Persona (1:1) Chat
    // ─────────────────────────────────────────────

    @MainActor
    func openSinglePersonaChat(personaType: PersonaType) {
        singleChatPersonaType = personaType
        singleChatMessages = []
        singleChatSession = nil
        isSingleChatLoading = false
        isSingleChatPresented = true
    }

    @MainActor
    func sendSingleChatMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSingleChatLoading,
              let pType = singleChatPersonaType else { return }

        isSingleChatLoading = true

        // Create session lazily on first message
        if singleChatSession == nil {
            let session = ChatSession(
                title: String(trimmed.prefix(40)),
                selectedPersonaTypeRaws: [pType.rawValue]
            )
            modelContext.insert(session)
            singleChatSession = session
            try? modelContext.save()
        }

        guard let session = singleChatSession else { return }

        let userMsg = ChatMessage(role: ChatRole.user, content: trimmed)
        userMsg.session = session
        modelContext.insert(userMsg)
        singleChatMessages.append(userMsg)
        try? modelContext.save()

        let history = singleChatMessages.suffix(6).map { msg -> String in
            let prefix = msg.role == ChatRole.user
                ? "사용자"
                : (msg.personaType?.localizedName ?? pType.localizedName)
            return "[\(prefix)] \(msg.content)"
        }.joined(separator: "\n")

        Task {
            let dto = await generateResponse(for: pType, query: trimmed, history: history)
            await MainActor.run {
                if let dto {
                    let msg = ChatMessage(
                        role: ChatRole.persona,
                        personaTypeRaw: dto.personaTypeRaw,
                        content: dto.content
                    )
                    msg.session = session
                    modelContext.insert(msg)
                    singleChatMessages.append(msg)
                }
                isSingleChatLoading = false
                try? modelContext.save()
            }
        }
    }

    @MainActor
    func closeSingleChat() {
        isSingleChatPresented = false
        singleChatPersonaType = nil
        singleChatSession = nil
        singleChatMessages = []
        isSingleChatLoading = false
    }

}

// MARK: - NodeManagerAgent helpers

extension GraphViewModel {
    /// Kick off the NodeManagerAgent in the background.
    /// Call after ecosystem sync or app foreground.
    @MainActor
    func runNodeManager() {
        let ctx = modelContext
        Task {
            await NodeManagerAgent.shared.run(context: ctx, viewModel: self)
        }
    }

    /// Runs scheduled daily analysis (≥08:00, once per calendar day).
    /// Call on every scene foreground activation.
    @MainActor
    func runScheduledAnalysis() {
        let ctx = modelContext
        Task {
            await NodeManagerAgent.shared.runScheduledAnalysisIfNeeded(context: ctx, viewModel: self)
        }
    }
}

// MARK: - Comparable clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
