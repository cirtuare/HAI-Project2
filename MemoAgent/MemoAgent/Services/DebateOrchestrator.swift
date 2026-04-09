// DebateOrchestrator.swift
// MemoAgent V2 — Multi-Agent Debate System
//
// Architecture (3-round debate):
//   Round 1 — Parallel independent analysis by Health AI + Work AI
//   Round 2 — Cross-domain rebuttals (forced disagreement to prevent sycophancy)
//   Round 3 — On-device synthesis via Apple Intelligence (sensitive data never combined in API)
//   ActionPlanBuilder — Creates NodeRecords, EdgeRecords, and EKReminders from synthesis
//
// Privacy: external APIs only receive single-domain summaries, never cross-domain raw data.
// The synthesis that combines both domains runs on-device.

import Foundation
import SwiftData
import FoundationModels
import EventKit

// MARK: - DebateError

enum DebateError: Error, LocalizedError {
    case noProviderAvailable
    case synthesisEmpty

    var errorDescription: String? {
        switch self {
        case .noProviderAvailable:
            return "AI 분석 프로바이더가 없습니다. 설정에서 API 키를 입력하거나 Apple Intelligence를 활성화하세요."
        case .synthesisEmpty:
            return "종합 분석 결과를 생성하지 못했습니다."
        }
    }
}

// MARK: - Generable schemas for Apple Intelligence

/// Used for free-text analysis/rebuttal turns via Apple Intelligence.
@Generable
struct DebateTextResponse {
    @Guide(description: "Complete analytical response text, thorough and detailed, in Korean")
    var text: String
}

/// Used for structured synthesis turn via Apple Intelligence.
@Generable
struct DebateSynthesisResult {
    @Guide(description: "Root cause analysis in 2-3 Korean sentences explaining the causal chain")
    var rootCause: String

    @Guide(description: "Exactly three concrete action items in Korean, each under 25 characters")
    var actions: [String]

    @Guide(description: "Urgency level: immediate (48시간 내), soon (1주 내), monitor (지속 관찰)")
    var urgency: String
}

// MARK: - SpecialistRole

private enum SpecialistRole: String {
    case health = "health"
    case work   = "work"

    var systemPrompt: String {
        switch self {
        case .health:
            return """
            당신은 건강 및 웰니스 전문 분석가입니다. 제공된 건강 데이터 요약을 분석하여 \
            패턴, 위험 요소, 근본 원인을 구체적으로 파악합니다.
            단순 나열이 아닌 인과관계와 메커니즘을 설명하세요. 가설을 명확히 진술하세요.
            응답 마지막 줄에 신뢰도를 표시하세요. 형식 예시: CONFIDENCE: 0.82
            """
        case .work:
            return """
            당신은 생산성 및 업무 관리 전문 분석가입니다. 제공된 태스크/일정 데이터 요약을 분석하여 \
            패턴, 병목점, 근본 원인을 구체적으로 파악합니다.
            단순 나열이 아닌 인과관계와 메커니즘을 설명하세요. 가설을 명확히 진술하세요.
            응답 마지막 줄에 신뢰도를 표시하세요. 형식 예시: CONFIDENCE: 0.79
            """
        }
    }

    var rebuttalPrompt: String {
        let domainLabel = self == .health ? "건강" : "업무"
        return """
        당신은 \(domainLabel) 분석 전문가입니다. 상대 에이전트의 분석을 검토하고 \
        반드시 최소 하나 이상의 구체적인 반론 또는 보완점을 제시하세요.
        모든 내용에 동의하더라도 놓친 한계점이나 대안 해석을 찾아야 합니다.
        인과관계 방향이나 타이밍에 특히 주목하세요.
        응답 마지막 줄에 수정된 신뢰도를 표시하세요. 형식 예시: CONFIDENCE: 0.88
        """
    }
}

// MARK: - SynthesisJSON (Codable — used for both API path decode and Apple Intelligence encode)

private struct SynthesisJSON: Codable {
    let rootCause: String
    let actions: [String]
    let urgency: String
}

// MARK: - DebateOrchestrator

actor DebateOrchestrator {
    static let shared = DebateOrchestrator()
    private init() {}

    private var activeHashes: Set<String> = []
    private let maxTranscriptChars = 3000
    private let maxTokensPerTurn = 800

    // MARK: - Entry Point

    /// Start a multi-agent debate for the given trigger.
    /// Runs entirely in the background; UI updates go through MainActor.
    func startDebate(trigger: DebateTrigger,
                     context: ModelContext,
                     viewModel: GraphViewModel) async {
        let hash = trigger.debateHash
        guard !activeHashes.contains(hash),
              !recentDebateExists(hash: hash, context: context) else { return }
        activeHashes.insert(hash)
        defer { activeHashes.remove(hash) }

        let record = DebateRecord(
            triggerDescription: trigger.patternDescription,
            status: "running",
            personaID: trigger.personaID,
            debateHash: hash
        )
        context.insert(record)
        try? context.save()
        await MainActor.run {
            viewModel.debateStatus = "AI 멀티 에이전트 분석 중..."
            viewModel.debateEvidenceNodeIDs = Set(trigger.evidenceNodeIDs)
        }

        do {
            var transcript: [AgentTurn] = []

            // ── Round 1: Parallel Independent Analysis ───────────────────────
            async let healthTask = callSpecialist(
                .health,
                summary: trigger.primaryDomainSummary,
                triggerContext: trigger.patternDescription
            )
            async let workTask = callSpecialist(
                .work,
                summary: trigger.secondaryDomainSummary,
                triggerContext: trigger.patternDescription
            )
            let healthTurn = try await healthTask
            let workTurn   = try await workTask
            transcript.append(contentsOf: [healthTurn, workTurn])

            // ── Round 2: Cross-Domain Rebuttals ───────────────────────────────
            let healthRebuttal = try await callRebuttal(
                .health, own: healthTurn.content, other: workTurn.content
            )
            let workRebuttal = try await callRebuttal(
                .work, own: workTurn.content, other: healthTurn.content
            )
            transcript.append(contentsOf: [healthRebuttal, workRebuttal])

            // ── Round 3: On-Device Synthesis ──────────────────────────────────
            let compressed = compressTranscript(transcript)
            let synthesis  = try await synthesize(compressed: compressed, trigger: trigger)
            guard !synthesis.content.isEmpty else { throw DebateError.synthesisEmpty }
            transcript.append(synthesis)

            // ── Action Plan ───────────────────────────────────────────────────
            let actionIDs = await buildActionPlan(
                synthesisContent: synthesis.content,
                trigger: trigger,
                context: context
            )

            // ── Persist ────────────────────────────────────────────────────────
            let transcriptData = (try? JSONEncoder().encode(transcript)) ?? Data()
            record.agentTranscriptJSON = transcriptData
            record.synthesisResult     = synthesis.content
            record.actionNodeIDs       = actionIDs
            record.status              = "completed"
            try? context.save()

            await MainActor.run {
                viewModel.activeDebateResult    = synthesis.content
                viewModel.debateStatus          = nil
                viewModel.debateEvidenceNodeIDs = []
                viewModel.refreshFromSwiftData()
            }
        } catch {
            record.status = "failed"
            try? context.save()
            await MainActor.run {
                viewModel.debateStatus          = nil
                viewModel.debateEvidenceNodeIDs = []
            }
        }
    }

    // MARK: - Round 1: Specialist Analysis

    private func callSpecialist(_ role: SpecialistRole,
                                 summary: String,
                                 triggerContext: String) async throws -> AgentTurn {
        let userMsg = """
        감지된 패턴 맥락: \(triggerContext)

        분석 데이터:
        \(summary)

        위 데이터를 분석하여 패턴, 근본 원인, 가설을 제시하세요.
        """
        let content = try await callBestProvider(system: role.systemPrompt, userMessage: userMsg)
        let confidence = extractConfidence(from: content)
        return AgentTurn(agentID: role.rawValue, role: "analysis", domain: role.rawValue,
                         content: content, confidence: confidence, timestamp: Date())
    }

    // MARK: - Round 2: Rebuttals

    private func callRebuttal(_ role: SpecialistRole,
                               own: String,
                               other: String) async throws -> AgentTurn {
        let userMsg = """
        내 1라운드 분석:
        \(String(own.prefix(700)))

        상대 에이전트 분석:
        \(String(other.prefix(700)))

        상대 분석에 대한 반론 또는 보완점을 제시하고, 인과관계 방향을 검토하세요.
        """
        let content = try await callBestProvider(system: role.rebuttalPrompt, userMessage: userMsg)
        let confidence = extractConfidence(from: content)
        return AgentTurn(agentID: "\(role.rawValue)-rebuttal", role: "rebuttal", domain: role.rawValue,
                         content: content, confidence: confidence, timestamp: Date())
    }

    // MARK: - Round 3: On-Device Synthesis (prefer Apple Intelligence for privacy)

    private func synthesize(compressed: String, trigger: DebateTrigger) async throws -> AgentTurn {
        let model = SystemLanguageModel.default
        var synthesisText = ""

        if case .available = model.availability {
            // Sensitive cross-domain synthesis stays on-device
            let instructions = """
            당신은 멀티 에이전트 토론 종합 분석가입니다. 건강 AI와 업무 AI의 토론을 바탕으로 \
            근본 원인, 우선순위 행동 계획(정확히 3개), 긴급도를 도출합니다. 한국어로 응답하세요.
            """
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "토론 요약:\n\(compressed)\n\n위 토론을 종합하여 핵심 원인과 행동 계획을 도출하세요.",
                generating: DebateSynthesisResult.self
            )
            let result = response.content
            // Re-encode as JSON string for consistent storage
            synthesisText = encodeToJSON(result)
        } else {
            // API fallback: ask for JSON output
            let instructions = """
            당신은 멀티 에이전트 토론 종합 분석가입니다.
            반드시 다음 JSON 형식만 출력하세요:
            {"rootCause": "근본 원인 2-3문장", "actions": ["행동1", "행동2", "행동3"], "urgency": "immediate|soon|monitor"}
            """
            synthesisText = try await callBestProvider(
                system: instructions,
                userMessage: "토론 요약:\n\(compressed)\n\nJSON으로 종합 분석하세요."
            )
        }

        return AgentTurn(agentID: "synthesizer", role: "synthesis", domain: "synthesizer",
                         content: synthesisText, confidence: 1.0, timestamp: Date())
    }

    private func encodeToJSON(_ result: DebateSynthesisResult) -> String {
        let obj = SynthesisJSON(rootCause: result.rootCause,
                                actions: result.actions,
                                urgency: result.urgency)
        guard let data = try? JSONEncoder().encode(obj),
              let str  = String(data: data, encoding: .utf8) else {
            return "{\"rootCause\": \"\(result.rootCause)\", \"actions\": [], \"urgency\": \"soon\"}"
        }
        return str
    }

    // MARK: - Action Plan Builder

    private func buildActionPlan(synthesisContent: String,
                                  trigger: DebateTrigger,
                                  context: ModelContext) async -> [String] {
        let parsed = parseSynthesisJSON(synthesisContent)
        let today  = ISO8601DateFormatter().string(from: Date()).prefix(10).description
        var createdIDs: [String] = []

        // Root-cause cluster node
        let rootCause = parsed?.rootCause ?? String(synthesisContent.prefix(200))
        let clusterTitle = "AI 분석: \(trigger.primaryDomain.rawValue) × \(trigger.secondaryDomain.rawValue)"
        let cluster = NodeRecord(
            title: clusterTitle,
            summary: rootCause,
            nodeTypeRaw: NodeType.aiCluster.rawValue,
            date: today,
            originalText: synthesisContent,
            isImportant: true,
            tags: ["AI 멀티에이전트", "패턴 분석", trigger.primaryDomain.rawValue, trigger.secondaryDomain.rawValue],
            positionX: Double.random(in: -250...250),
            positionY: Double.random(in: -250...250),
            sourceSystemRaw: SourceSystem.aiGenerated.rawValue,
            personaID: trigger.personaID,
            isProcessed: true
        )
        context.insert(cluster)
        createdIDs.append(cluster.id)

        // Action item nodes
        let actions = parsed?.actions ?? defaultActions(from: synthesisContent)
        for (i, action) in actions.prefix(3).enumerated() {
            let actionNode = NodeRecord(
                title: action,
                summary: "AI 분석 기반 행동 항목 \(i + 1) / 3",
                nodeTypeRaw: NodeType.reminder.rawValue,
                date: today,
                originalText: action,
                isImportant: i == 0,
                tags: ["AI 행동 계획"],
                positionX: cluster.positionX + Double(i - 1) * 220,
                positionY: cluster.positionY + 200,
                sourceSystemRaw: SourceSystem.aiGenerated.rawValue,
                personaID: trigger.personaID,
                isProcessed: true
            )
            context.insert(actionNode)
            createdIDs.append(actionNode.id)

            context.insert(EdgeRecord(
                sourceID: cluster.id,
                targetID: actionNode.id,
                relationship: "실행 항목",
                strokeWidth: 1.5,
                isAnimated: i == 0,
                isUserCreated: false
            ))

            if i == 0 { createEKReminderIfPossible(title: action) }
        }

        // Edges from evidence nodes → cluster
        for evidenceID in trigger.evidenceNodeIDs.prefix(5) {
            guard !edgeExists(source: evidenceID, target: cluster.id, context: context) else { continue }
            context.insert(EdgeRecord(
                sourceID: evidenceID,
                targetID: cluster.id,
                relationship: "근거",
                strokeWidth: 1,
                isAnimated: false,
                isUserCreated: false
            ))
        }

        try? context.save()
        return createdIDs
    }

    // MARK: - EKReminder creation

    private func createEKReminderIfPossible(title: String) {
        guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return }
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        reminder.dueDateComponents = components
        reminder.calendar = store.defaultCalendarForNewReminders()
        try? store.save(reminder, commit: true)
    }

    // MARK: - Provider routing

    /// Route to the user's selected provider.
    /// Apple Intelligence specialist calls use @Generable DebateTextResponse.
    private func callBestProvider(system: String, userMessage: String) async throws -> String {
        let mgr = AIProviderManager.shared
        let provider = mgr.selectedProvider

        if provider == .appleIntelligence {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                throw DebateError.noProviderAvailable
            }
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(
                to: userMessage,
                generating: DebateTextResponse.self
            )
            return response.content.text
        }
        return try await mgr.callAI(provider: provider,
                                     system: system,
                                     userMessage: userMessage,
                                     maxTokens: maxTokensPerTurn)
    }

    // MARK: - Transcript compression

    private func compressTranscript(_ turns: [AgentTurn]) -> String {
        let full = turns.map { "[\($0.agentID)] \($0.content)" }.joined(separator: "\n\n---\n\n")
        guard full.count > maxTranscriptChars else { return full }
        return turns.map { turn in
            "[\(turn.agentID)] (신뢰도: \(String(format: "%.2f", turn.confidence)))\n\(String(turn.content.prefix(500)))..."
        }.joined(separator: "\n\n---\n\n")
    }

    // MARK: - Helpers

    private func extractConfidence(from text: String) -> Double {
        let pattern = #"CONFIDENCE:\s*(0\.\d{1,2}|1\.0)"#
        guard let range = text.range(of: pattern, options: .regularExpression),
              let numRange = text[range].range(of: #"(0\.\d{1,2}|1\.0)"#, options: .regularExpression)
        else { return 0.75 }
        return Double(String(text[range][numRange])) ?? 0.75
    }

    private func parseSynthesisJSON(_ text: String) -> SynthesisJSON? {
        guard let start = text.firstIndex(of: "{"),
              let end   = text.lastIndex(of: "}") else { return nil }
        let jsonStr = String(text[start...end])
        guard let data = jsonStr.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SynthesisJSON.self, from: data)
    }

    private func defaultActions(from text: String) -> [String] {
        let lines = text.components(separatedBy: "\n").filter {
            $0.hasPrefix("1.") || $0.hasPrefix("2.") || $0.hasPrefix("3.") ||
            $0.hasPrefix("- ") || $0.hasPrefix("• ")
        }.map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count >= 2 else {
            return ["현재 부담 즉시 경감", "충분한 휴식 확보", "우선순위 재조정"]
        }
        return Array(lines.prefix(3))
    }

    private func edgeExists(source: String, target: String, context: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<EdgeRecord>(
            predicate: #Predicate { $0.sourceID == source && $0.targetID == target }
        )
        return (try? context.fetch(descriptor).first) != nil
    }

    private func recentDebateExists(hash: String, context: ModelContext) -> Bool {
        let cutoff = Date().addingTimeInterval(-86400)
        let all = (try? context.fetch(FetchDescriptor<DebateRecord>())) ?? []
        return all.contains {
            $0.debateHash == hash &&
            $0.createdAt >= cutoff &&
            $0.status != "failed"
        }
    }
}
