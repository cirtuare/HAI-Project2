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

    private let lastRunKey       = "nodemind.nodemanager.lastrun"
    private let lastPatternKey   = "nodemind.nodemanager.lastpattern"
    private let lastScheduledKey = "nodemind.nodemanager.lastscheduled"

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

        // Persona threshold check: suggest new personas if node density warrants it
        await checkPersonaThresholds(context: context, viewModel: viewModel)

        // Cross-domain pattern detection — throttled separately (once per day)
        await runPatternDetectionIfNeeded(context: context, viewModel: viewModel)
    }

    // MARK: - Scheduled Analysis (6-3: 매일 오전 8시, 주간 인사이트)

    /// Called on every app foreground. Runs full analysis once per calendar day
    /// after 08:00, and generates a weekly insight node on Sundays.
    func runScheduledAnalysisIfNeeded(context: ModelContext, viewModel: GraphViewModel) async {
        let calendar = Calendar.current
        let now      = Date()
        let hour     = calendar.component(.hour, from: now)

        // Only run at 08:00 or later
        guard hour >= 8 else { return }

        // Skip if already ran today
        if let lastRun = UserDefaults.standard.object(forKey: lastScheduledKey) as? Date,
           calendar.isDateInToday(lastRun) { return }

        UserDefaults.standard.set(now, forKey: lastScheduledKey)

        // Full node-manager pass
        await run(context: context, viewModel: viewModel)

        // Weekly insight on Sundays (weekday == 1 in Calendar.current)
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 {
            await generateWeeklyInsightNode(context: context, viewModel: viewModel)
        }
    }

    /// Generates a summary node covering the past 7 days' activity across all domains.
    private func generateWeeklyInsightNode(context: ModelContext, viewModel: GraphViewModel) async {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let allNodes     = (try? context.fetch(FetchDescriptor<NodeRecord>())) ?? []
        let recent       = allNodes.filter { $0.createdAt >= sevenDaysAgo && !$0.isProcessed == false }
        guard recent.count >= 3 else { return }

        // Domain breakdown
        let bySource = Dictionary(grouping: recent) { $0.sourceSystemRaw }
        let breakdown = bySource
            .sorted { $0.value.count > $1.value.count }
            .prefix(4)
            .map { pair -> String in
                let label = SourceSystem(rawValue: pair.key)?.localizedLabel ?? pair.key
                return "\(label) \(pair.value.count)개"
            }
            .joined(separator: ", ")

        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let today = String(format: "%04d-%02d-%02d",
                           comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)

        let insightNode = NodeRecord(
            title: "주간 인사이트 · \(today)",
            summary: "지난 7일간 \(recent.count)개의 지식 블록이 생성됐습니다. [\(breakdown)]",
            nodeTypeRaw: NodeType.aiCluster.rawValue,
            date: today,
            originalText: "자동 생성 주간 요약 — \(breakdown)",
            isImportant: true,
            tags: ["주간 인사이트", "자동 분석"],
            positionX: Double.random(in: -180...180),
            positionY: Double.random(in: -180...180),
            sourceSystemRaw: SourceSystem.aiGenerated.rawValue,
            personaIDs: [fetchActivePersonaID(context: context)].compactMap { $0 },
            isProcessed: true
        )
        context.insert(insightNode)
        try? context.save()

        await NotificationService.shared.sendWeeklyInsightNotification(nodeCount: recent.count)
        await MainActor.run { viewModel.refreshFromSwiftData() }
    }

    // MARK: - Cross-Domain Pattern Detection

    /// Detect cross-domain patterns and trigger a multi-agent debate if urgency is high enough.
    func runPatternDetection(context: ModelContext, viewModel: GraphViewModel) async {
        await runPatternDetectionIfNeeded(context: context, viewModel: viewModel)
    }

    private func runPatternDetectionIfNeeded(context: ModelContext, viewModel: GraphViewModel) async {
        if let last = UserDefaults.standard.object(forKey: lastPatternKey) as? Date,
           Date().timeIntervalSince(last) < 86400 { return }

        guard let trigger = detectBestCrossDomainPattern(context: context) else { return }
        UserDefaults.standard.set(Date(), forKey: lastPatternKey)
        await DebateOrchestrator.shared.startDebate(trigger: trigger, context: context, viewModel: viewModel)
    }

    /// Evaluates all supported cross-domain pattern pairs and returns
    /// the highest-urgency trigger, or nil if no pair meets the threshold.
    private func detectBestCrossDomainPattern(context: ModelContext) -> DebateTrigger? {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        // ── Fetch nodes by domain ──────────────────────────────────────────
        let healthNodes   = fetchNodes(ofType: .healthMetric,  context: context)
            .filter { isWithin(date: $0.date, since: sevenDaysAgo) }
        let reminderNodes = fetchNodes(ofType: .reminder,      context: context)
            .filter { isWithin(date: $0.date, since: sevenDaysAgo) }
        let calendarNodes = fetchNodes(ofType: .calendarEvent, context: context)
            .filter { isWithin(date: $0.date, since: sevenDaysAgo) }
        let financeNodes  = fetchNodesBySource(.finance,  context: context)
            .filter { isWithin(date: $0.date, since: sevenDaysAgo) }
        let photoNodes    = fetchNodesBySource(.photos,   context: context)
            .filter { isWithin(date: $0.date, since: sevenDaysAgo) }
        let workNodes     = reminderNodes + calendarNodes

        // ── Evaluate each domain pair ──────────────────────────────────────
        let candidates: [DebateTrigger?] = [
            evaluateHealthWork(health: healthNodes, work: workNodes,
                               all: healthNodes + workNodes,
                               personaID: fetchActivePersonaID(context: context)),
            evaluateHealthFinance(health: healthNodes, finance: financeNodes,
                                  personaID: fetchActivePersonaID(context: context)),
            evaluateFinanceHobby(finance: financeNodes, hobby: photoNodes,
                                 personaID: fetchActivePersonaID(context: context)),
            evaluateAcademicHealth(academic: workNodes, health: healthNodes,
                                   personaID: fetchActivePersonaID(context: context)),
        ]

        return candidates
            .compactMap { $0 }
            .max(by: { $0.urgencyScore < $1.urgencyScore })
    }

    // MARK: Pattern: Health ↔ Work (original)

    private func evaluateHealthWork(health: [NodeRecord], work: [NodeRecord],
                                    all: [NodeRecord],
                                    personaID: String?) -> DebateTrigger? {
        guard !health.isEmpty, !work.isEmpty else { return nil }

        var score = 0.0
        var signals: [String] = []

        let sleepCount = health.filter {
            $0.tags.contains("수면") || $0.title.localizedCaseInsensitiveContains("수면")
        }.count
        if sleepCount >= 2 {
            score += 0.3; signals.append("수면 기록 \(sleepCount)개")
        } else if !health.isEmpty {
            score += 0.15; signals.append("건강 데이터 \(health.count)개")
        }
        if work.count >= 5 { score += 0.3; signals.append("업무 항목 \(work.count)개") }
        else if work.count >= 2 { score += 0.15; signals.append("업무 항목 \(work.count)개") }
        if health.count >= 3 && work.count >= 3 {
            score += 0.2; signals.append("건강×업무 교차")
        }

        guard score >= 0.6 else { return nil }

        return DebateTrigger(
            primaryDomain: .health, secondaryDomain: .work,
            evidenceNodeIDs: all.prefix(5).map { $0.id },
            patternDescription: "건강×업무 패턴: \(signals.joined(separator: " | "))",
            urgencyScore: score,
            primaryDomainSummary: health.prefix(8).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"),
            secondaryDomainSummary: work.prefix(8).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"),
            personaID: personaID
        )
    }

    // MARK: Pattern: Health ↔ Finance

    private func evaluateHealthFinance(health: [NodeRecord], finance: [NodeRecord],
                                       personaID: String?) -> DebateTrigger? {
        guard health.count >= 2, finance.count >= 2 else { return nil }

        var score = 0.0
        var signals: [String] = []

        // Stress + spending spike
        let stressNodes = health.filter {
            $0.tags.contains("스트레스") || $0.title.localizedCaseInsensitiveContains("심박")
        }
        if !stressNodes.isEmpty {
            score += 0.35; signals.append("스트레스 지표 \(stressNodes.count)개")
        }
        if finance.count >= 3 {
            score += 0.3; signals.append("금융 기록 \(finance.count)개")
        }
        if health.count >= 2 && finance.count >= 2 {
            score += 0.2; signals.append("건강×금융 교차")
        }

        guard score >= 0.6 else { return nil }

        return DebateTrigger(
            primaryDomain: .health, secondaryDomain: .finance,
            evidenceNodeIDs: (health + finance).prefix(5).map { $0.id },
            patternDescription: "건강×금융 패턴: \(signals.joined(separator: " | "))",
            urgencyScore: score,
            primaryDomainSummary: health.prefix(8).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"),
            secondaryDomainSummary: finance.prefix(8).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"),
            personaID: personaID
        )
    }

    // MARK: Pattern: Finance ↔ Hobby

    private func evaluateFinanceHobby(finance: [NodeRecord], hobby: [NodeRecord],
                                      personaID: String?) -> DebateTrigger? {
        guard finance.count >= 2, hobby.count >= 2 else { return nil }

        var score = 0.0
        var signals: [String] = []

        if finance.count >= 3 { score += 0.3; signals.append("금융 기록 \(finance.count)개") }
        if hobby.count >= 3   { score += 0.3; signals.append("취미 활동 \(hobby.count)개") }
        if finance.count >= 2 && hobby.count >= 2 {
            score += 0.25; signals.append("금융×취미 교차")
        }

        guard score >= 0.6 else { return nil }

        return DebateTrigger(
            primaryDomain: .finance, secondaryDomain: .personal,
            evidenceNodeIDs: (finance + hobby).prefix(5).map { $0.id },
            patternDescription: "금융×취미 패턴: \(signals.joined(separator: " | "))",
            urgencyScore: score,
            primaryDomainSummary: finance.prefix(8).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"),
            secondaryDomainSummary: hobby.prefix(8).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"),
            personaID: personaID
        )
    }

    // MARK: Pattern: Academic ↔ Health

    private func evaluateAcademicHealth(academic: [NodeRecord], health: [NodeRecord],
                                        personaID: String?) -> DebateTrigger? {
        guard academic.count >= 3, health.count >= 2 else { return nil }

        var score = 0.0
        var signals: [String] = []

        let studyNodes = academic.filter {
            $0.tags.contains("학습") || $0.tags.contains("공부") ||
            $0.title.localizedCaseInsensitiveContains("학습")
        }
        if studyNodes.count >= 2 { score += 0.3; signals.append("학습 항목 \(studyNodes.count)개") }
        else if !academic.isEmpty { score += 0.15; signals.append("학업 기록 \(academic.count)개") }

        let sleepCount = health.filter {
            $0.tags.contains("수면") || $0.title.localizedCaseInsensitiveContains("수면")
        }.count
        if sleepCount >= 2 { score += 0.3; signals.append("수면 기록 \(sleepCount)개") }
        else if !health.isEmpty { score += 0.15; signals.append("건강 데이터 \(health.count)개") }

        if academic.count >= 3 && health.count >= 2 {
            score += 0.2; signals.append("학업×건강 교차")
        }

        guard score >= 0.6 else { return nil }

        return DebateTrigger(
            primaryDomain: .academic, secondaryDomain: .health,
            evidenceNodeIDs: (academic + health).prefix(5).map { $0.id },
            patternDescription: "학업×건강 패턴: \(signals.joined(separator: " | "))",
            urgencyScore: score,
            primaryDomainSummary: academic.prefix(8).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"),
            secondaryDomainSummary: health.prefix(8).map { "- \($0.title): \($0.summary)" }.joined(separator: "\n"),
            personaID: personaID
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

        let clusterPersonaIDs = nodes.first?.personaIDs ?? []
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
            personaIDs: clusterPersonaIDs,
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

    // MARK: - Persona Threshold Check

    private static let personaThreshold = 10

    /// Maps SourceSystem → PersonaType for threshold inference.
    /// Nodes whose source clearly belongs to a domain are counted toward that domain.
    private static let sourceToPersonaType: [SourceSystem: PersonaType] = [
        .healthKit:  .health,
        .screenTime: .health,
        .finance:    .finance,
        .photos:     .hobby,
    ]

    /// Count unattached nodes by inferred PersonaType.
    /// "Unattached" means no persona assignment (both legacy personaID nil and personaIDs empty).
    private func countNodesByInferredPersonaType(context: ModelContext) -> [PersonaType: Int] {
        let descriptor = FetchDescriptor<NodeRecord>(
            predicate: #Predicate { $0.personaID == nil && $0.personaIDs.isEmpty }
        )
        let nodes = (try? context.fetch(descriptor)) ?? []
        var counts: [PersonaType: Int] = [:]
        for node in nodes {
            guard let source = SourceSystem(rawValue: node.sourceSystemRaw),
                  let pType = Self.sourceToPersonaType[source] else { continue }
            counts[pType, default: 0] += 1
        }
        return counts
    }

    /// If any PersonaType has ≥ threshold unattached nodes but no corresponding
    /// PersonaRecord exists yet, surface a suggestion via GraphViewModel.
    private func checkPersonaThresholds(context: ModelContext, viewModel: GraphViewModel) async {
        let counts = countNodesByInferredPersonaType(context: context)
        guard !counts.isEmpty else { return }

        // Fetch existing persona types
        let descriptor = FetchDescriptor<PersonaRecord>()
        let existingTypes = Set(
            ((try? context.fetch(descriptor)) ?? []).compactMap { $0.personaType }
        )

        // Pick the type with the highest count that exceeds threshold and is missing
        let suggestion = counts
            .filter { $0.value >= Self.personaThreshold && !existingTypes.contains($0.key) }
            .max(by: { $0.value < $1.value })
            .map { $0.key }

        guard let suggested = suggestion else { return }

        await MainActor.run {
            // Only update if not already showing a suggestion
            if viewModel.pendingPersonaSuggestion == nil {
                viewModel.pendingPersonaSuggestion = suggested
            }
        }
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

    private func fetchNodesBySource(_ source: SourceSystem, context: ModelContext) -> [NodeRecord] {
        let raw = source.rawValue
        let descriptor = FetchDescriptor<NodeRecord>(
            predicate: #Predicate { $0.sourceSystemRaw == raw }
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

