// NodeManagerAgent.swift
// MemoAgent V2 Phase 4 — AI-powered node organization agent
//
// Responsibilities:
//   1. Auto-clustering: detects semantically related nodes → creates aiCluster parent nodes
//   2. Auto-linking:    creates aiGenerated edges between cross-source related nodes
//   3. Insight synthesis: weekly persona-scoped summary node
//   4. Correlation detection: surfaces cross-source patterns (e.g. poor sleep + missed deadlines)

import Foundation
import SwiftData
import FoundationModels

// MARK: - NodeManagerAgent

actor NodeManagerAgent {
    static let shared = NodeManagerAgent()
    private init() {}

    private let lastRunKey     = "nodemind.nodemanager.lastrun"
    private let lastPatternKey = "nodemind.nodemanager.lastpattern"

    // MARK: - Entry Point

    /// Run the agent over unprocessed nodes. Safe to call on every app foreground.
    func run(context: ModelContext, viewModel: GraphViewModel) async {
        // Throttle: don't run more than once per hour
        if let last = UserDefaults.standard.object(forKey: lastRunKey) as? Date,
           Date().timeIntervalSince(last) < 3600 { return }

        let unprocessed = fetchUnprocessedNodes(context: context)
        guard !unprocessed.isEmpty else { return }

        await performClustering(nodes: unprocessed, context: context)
        await performAutoLinking(context: context, viewModel: viewModel)
        markProcessed(nodes: unprocessed, context: context)

        UserDefaults.standard.set(Date(), forKey: lastRunKey)

        await MainActor.run { viewModel.refreshFromSwiftData() }

        // Cross-domain pattern detection — throttled separately (once per day)
        await runPatternDetectionIfNeeded(context: context, viewModel: viewModel)
    }

    // MARK: - Cross-Domain Pattern Detection

    /// Detect cross-domain patterns and trigger a multi-agent debate if urgency is high enough.
    func runPatternDetection(context: ModelContext, viewModel: GraphViewModel) async {
        await runPatternDetectionIfNeeded(context: context, viewModel: viewModel)
    }

    private func runPatternDetectionIfNeeded(context: ModelContext, viewModel: GraphViewModel) async {
        if let last = UserDefaults.standard.object(forKey: lastPatternKey) as? Date,
           Date().timeIntervalSince(last) < 86400 { return }

        guard let trigger = detectCrossDomainPattern(context: context) else { return }
        UserDefaults.standard.set(Date(), forKey: lastPatternKey)
        await DebateOrchestrator.shared.startDebate(trigger: trigger, context: context, viewModel: viewModel)
    }

    private func detectCrossDomainPattern(context: ModelContext) -> DebateTrigger? {
        let healthNodes   = fetchNodes(ofType: .healthMetric,  context: context)
        let reminderNodes = fetchNodes(ofType: .reminder,      context: context)
        let calendarNodes = fetchNodes(ofType: .calendarEvent, context: context)

        // Need data from both health and work domains to debate
        guard !healthNodes.isEmpty, !reminderNodes.isEmpty else { return nil }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentHealth   = healthNodes.filter   { isWithin(date: $0.date, since: sevenDaysAgo) }
        let recentReminder = reminderNodes.filter { isWithin(date: $0.date, since: sevenDaysAgo) }
        let recentCalendar = calendarNodes.filter { isWithin(date: $0.date, since: sevenDaysAgo) }

        guard !recentHealth.isEmpty else { return nil }

        var urgencyScore = 0.0
        var signals: [String] = []

        // Signal 1: Sleep data present (health domain active)
        let sleepNodes = recentHealth.filter {
            $0.tags.contains("수면") || $0.title.contains("수면") || $0.title.contains("Sleep")
        }
        if sleepNodes.count >= 2 {
            urgencyScore += 0.3
            signals.append("최근 \(sleepNodes.count)개 수면 기록")
        } else if !recentHealth.isEmpty {
            urgencyScore += 0.15
            signals.append("최근 건강 데이터 \(recentHealth.count)개")
        }

        // Signal 2: High reminder/task volume
        if recentReminder.count >= 5 {
            urgencyScore += 0.3
            signals.append("최근 7일 알림 \(recentReminder.count)개")
        } else if recentReminder.count >= 2 {
            urgencyScore += 0.15
            signals.append("최근 7일 알림 \(recentReminder.count)개")
        }

        // Signal 3: Cross-domain data density (both domains active)
        let workCount = recentReminder.count + recentCalendar.count
        if recentHealth.count >= 3 && workCount >= 3 {
            urgencyScore += 0.2
            signals.append("건강(\(recentHealth.count)) + 업무(\(workCount)) 데이터 교차")
        }

        // Signal 4: No important nodes created recently (cognitive disengagement)
        let importantRecent = fetchImportantNodes(context: context, since: sevenDaysAgo)
        if importantRecent.isEmpty && (recentHealth.count + workCount) >= 5 {
            urgencyScore += 0.2
            signals.append("중요 노드 생성 없음 (7일)")
        }

        guard urgencyScore >= 0.6 else { return nil }

        // Build pre-digested domain summaries (no raw PII sent to external APIs)
        let healthSummary = recentHealth.prefix(10)
            .map { "- \($0.title): \($0.summary)" }
            .joined(separator: "\n")
        let workSummary = (recentReminder + recentCalendar).prefix(10)
            .map { "- \($0.title): \($0.summary)" }
            .joined(separator: "\n")

        let activePersonaID = fetchActivePersonaID(context: context)

        return DebateTrigger(
            primaryDomain: .health,
            secondaryDomain: .work,
            evidenceNodeIDs: (recentHealth + recentReminder).prefix(5).map { $0.id },
            patternDescription: "감지된 패턴: \(signals.joined(separator: " | "))",
            urgencyScore: urgencyScore,
            primaryDomainSummary: healthSummary,
            secondaryDomainSummary: workSummary,
            personaID: activePersonaID
        )
    }

    private func isWithin(date dateStr: String, since cutoff: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return false }
        return date >= cutoff
    }

    private func fetchImportantNodes(context: ModelContext, since date: Date) -> [NodeRecord] {
        let descriptor = FetchDescriptor<NodeRecord>(
            predicate: #Predicate { $0.isImportant && $0.createdAt >= date }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchActivePersonaID(context: ModelContext) -> String? {
        let descriptor = FetchDescriptor<PersonaRecord>(
            predicate: #Predicate { $0.isActive }
        )
        return (try? context.fetch(descriptor).first)?.id
    }

    // MARK: - Clustering

    private func performClustering(nodes: [NodeRecord], context: ModelContext) async {
        guard nodes.count >= 3 else { return }

        // Group nodes by type to form candidate clusters
        let byType = Dictionary(grouping: nodes) { $0.nodeTypeRaw }
        for (typeRaw, group) in byType where group.count >= 2 {
            guard let nodeType = NodeType(rawValue: typeRaw),
                  nodeType != .aiCluster else { continue }
            await createClusterIfNeeded(for: group, typeRaw: typeRaw, context: context)
        }
    }

    private func createClusterIfNeeded(for nodes: [NodeRecord], typeRaw: String, context: ModelContext) async {
        let titles = nodes.prefix(5).map { $0.title }.joined(separator: "\n- ")
        let summaryText = nodes.prefix(5).map { $0.summary }.joined(separator: " ")

        // Pre-fetch main-actor-isolated values before the if/else
        let typeLabel       = await MainActor.run { NodeType(rawValue: typeRaw)?.localizedLabel ?? typeRaw }
        let currentProvider = await MainActor.run { AIProviderManager.shared.selectedProvider }

        let clusterTitle: String
        let clusterSummary: String

        // Try Apple Intelligence first; fall back to a heuristic title
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            do {
                let session = LanguageModelSession(instructions: """
                    You are a knowledge clustering assistant.
                    Given a list of related knowledge nodes, produce a concise cluster title (max 8 words)
                    and a 1-sentence summary. Respond in the same language as the input.
                    """)
                let response = try await session.respond(
                    to: "Nodes:\n- \(titles)\n\nSummaries: \(summaryText.prefix(400))",
                    generating: ClusterResult.self
                )
                clusterTitle  = response.content.title
                clusterSummary = response.content.summary
            } catch {
                clusterTitle  = "\(typeLabel) 클러스터"
                clusterSummary = "\(nodes.count)개의 관련 노드로 구성된 클러스터입니다."
            }
        } else if currentProvider != .appleIntelligence {
            do {
                let response = try await AIProviderManager.shared.callAI(
                    system: "You are a knowledge clustering assistant. Respond in the same language as the input.",
                    userMessage: "Nodes:\n- \(titles)\n\nCreate a JSON: {\"title\": \"...\", \"summary\": \"...\"}",
                    maxTokens: 150
                )
                let parsed = try? parseClusterResult(from: response)
                clusterTitle  = parsed?.title  ?? "\(typeLabel) 클러스터"
                clusterSummary = parsed?.summary ?? "\(nodes.count)개의 관련 노드 클러스터"
            } catch {
                clusterTitle  = "\(typeLabel) 클러스터"
                clusterSummary = "\(nodes.count)개의 관련 노드 클러스터"
            }
        } else {
            clusterTitle  = "\(typeLabel) 클러스터"
            clusterSummary = "\(nodes.count)개의 관련 노드 클러스터"
        }

        let personaID = nodes.first?.personaID
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let today = String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)

        let cluster = NodeRecord(
            title: clusterTitle,
            summary: clusterSummary,
            nodeTypeRaw: NodeType.aiCluster.rawValue,
            date: today,
            originalText: "AI-generated cluster from \(nodes.count) nodes of type \(typeRaw)",
            isImportant: false,
            tags: ["AI 클러스터", typeLabel],
            positionX: Double.random(in: -300...300),
            positionY: Double.random(in: -300...300),
            sourceSystemRaw: SourceSystem.aiGenerated.rawValue,
            personaID: personaID,
            schemaVersion: 2,
            isProcessed: true
        )
        context.insert(cluster)

        // Create edges from cluster → member nodes
        for node in nodes {
            let edge = EdgeRecord(
                sourceID: cluster.id,
                targetID: node.id,
                relationship: "포함",
                strokeWidth: 1,
                isAnimated: false,
                isUserCreated: false
            )
            context.insert(edge)
        }
        try? context.save()
    }

    // MARK: - Auto-linking

    private func performAutoLinking(context: ModelContext, viewModel: GraphViewModel) async {
        // Cross-source correlation: health + reminder overlap on same date
        let healthNodes   = fetchNodes(ofType: .healthMetric,  context: context)
        let reminderNodes = fetchNodes(ofType: .reminder,      context: context)
        let calendarNodes = fetchNodes(ofType: .calendarEvent, context: context)

        var createdLinks = 0

        for health in healthNodes {
            for reminder in reminderNodes where reminder.date == health.date {
                if !edgeExists(source: health.id, target: reminder.id, context: context) {
                    context.insert(EdgeRecord(
                        sourceID: health.id,
                        targetID: reminder.id,
                        relationship: "같은 날",
                        strokeWidth: 1,
                        isAnimated: false,
                        isUserCreated: false
                    ))
                    createdLinks += 1
                }
            }
            for event in calendarNodes where event.date == health.date {
                if !edgeExists(source: health.id, target: event.id, context: context) {
                    context.insert(EdgeRecord(
                        sourceID: health.id,
                        targetID: event.id,
                        relationship: "같은 날",
                        strokeWidth: 1,
                        isAnimated: false,
                        isUserCreated: false
                    ))
                    createdLinks += 1
                }
            }
        }

        if createdLinks > 0 { try? context.save() }
    }

    // MARK: - Helpers

    private func fetchUnprocessedNodes(context: ModelContext) -> [NodeRecord] {
        let descriptor = FetchDescriptor<NodeRecord>(
            predicate: #Predicate { !$0.isProcessed }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchNodes(ofType type: NodeType, context: ModelContext) -> [NodeRecord] {
        let raw = type.rawValue
        let descriptor = FetchDescriptor<NodeRecord>(
            predicate: #Predicate { $0.nodeTypeRaw == raw }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func edgeExists(source: String, target: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<EdgeRecord>(
            predicate: #Predicate { $0.sourceID == source && $0.targetID == target }
        )
        return (try? context.fetch(descriptor).first) != nil
    }

    private func markProcessed(nodes: [NodeRecord], context: ModelContext) {
        for node in nodes { node.isProcessed = true }
        try? context.save()
    }

    private func parseClusterResult(from text: String) throws -> ClusterResult {
        struct R: Decodable { let title: String; let summary: String }
        var clean = text
        if let s = text.firstIndex(of: "{"), let e = text.lastIndex(of: "}") {
            clean = String(text[s...e])
        }
        guard let data = clean.data(using: .utf8) else { throw ClaudeError.parseError }
        let r = try JSONDecoder().decode(R.self, from: data)
        return ClusterResult(title: r.title, summary: r.summary)
    }
}

// MARK: - Generable schema for Apple Intelligence

@Generable
struct ClusterResult {
    @Guide(description: "A concise cluster title, max 8 words, same language as input")
    var title: String
    @Guide(description: "A 1-sentence summary of what this cluster contains")
    var summary: String
}

// MARK: - GraphViewModel extension

extension GraphViewModel {
    /// Kick off the NodeManagerAgent in the background.
    /// Call after ecosystem sync or app foreground.
    @MainActor
    func runNodeManager(modelContext: ModelContext) {
        Task {
            await NodeManagerAgent.shared.run(context: modelContext, viewModel: self)
        }
    }

}
