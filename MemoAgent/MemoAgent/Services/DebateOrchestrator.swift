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

    @Guide(description: "Expected utility score (0.0-1.0) for each action item in the same order as actions")
    var actionScores: [Double]

    @Guide(description: "Urgency level: immediate (48시간 내), soon (1주 내), monitor (지속 관찰)")
    var urgency: String

    @Guide(description: "true if all agents clearly agreed on a solution; false if key points still conflict")
    var consensusReached: Bool

    @Guide(description: "If consensusReached is false: exactly 2-3 clarifying questions for the human. Empty array if consensus was reached.")
    var reverseQuestions: [String]
}

// MARK: - SpecialistRole

private enum SpecialistRole: String {
    case health   = "health"
    case work     = "work"
    case finance  = "finance"
    case hobby    = "hobby"
    case academic = "academic"

    /// Map a PersonaType to the matching SpecialistRole.
    nonisolated static func from(_ personaType: PersonaType) -> SpecialistRole {
        switch personaType {
        case .health:   return .health
        case .academic: return .academic
        case .finance:  return .finance
        case .hobby:    return .hobby
        case .other:    return .hobby   // fallback: general-purpose uses hobby role
        }
    }

    var domainLabel: String {
        switch self {
        case .health:   return "건강"
        case .work:     return "업무"
        case .finance:  return "금융"
        case .hobby:    return "취미"
        case .academic: return "학업"
        }
    }

    var systemPrompt: String {
        switch self {
        case .health:   return PromptStore.shared.prompt(for: .debateSpecialistHealth)
        case .work:     return PromptStore.shared.prompt(for: .debateSpecialistWork)
        case .finance:  return PromptStore.shared.prompt(for: .debateSpecialistFinance)
        case .hobby:    return PromptStore.shared.prompt(for: .debateSpecialistHobby)
        case .academic: return PromptStore.shared.prompt(for: .debateSpecialistAcademic)
        }
    }

    var rebuttalPrompt: String {
        PromptStore.shared.prompt(for: .debateRebuttalTemplate, replacing: "domainLabel", with: domainLabel)
    }
}

// MARK: - SynthesisJSON
// Not Codable — uses JSONSerialization to avoid @MainActor inference
// caused by @Generable macros in this file.

private struct SynthesisJSON: Sendable {
    let rootCause: String
    let actions: [String]
    let actionScores: [Double]
    let urgency: String
    let consensusReached: Bool
    let reverseQuestions: [String]
}

// MARK: - DebateOrchestrator

actor DebateOrchestrator {
    static let shared = DebateOrchestrator()
    private init() {}

    private var activeHashes: Set<String> = []
    private let maxTranscriptChars = 3000
    private let maxTokensPerTurn = 800

    /// Stores the in-progress transcript while waiting for human input (HITL mode).
    private var pendingHITLTranscript: [AgentTurn] = []

    /// Called on the MainActor each time an AgentTurn completes (for live visualization).
    var onTurnCompleted: (@Sendable (AgentTurn) -> Void)? = nil

    // MARK: - HITL: clear pending state (e.g., on reset)
    func clearPendingHITL() {
        pendingHITLTranscript = []
    }

    // MARK: - Manual Trigger (user-initiated from MultiPersonaChatView)

    /// Runs a debate for any persona combination chosen by the user.
    func startManualDebate(personaTypes: [PersonaType],
                            query: String,
                            personaSummaries: [PersonaType: String] = [:],
                            context: ModelContext,
                            viewModel: GraphViewModel) async {
        guard personaTypes.count >= 2 else { return }
        let roles = personaTypes.map { SpecialistRole.from($0) }

        let record = DebateRecord(
            triggerDescription: "수동 토론: \(String(query.prefix(60)))",
            status: "running",
            personaID: nil,
            debateHash: "manual-\(Int(Date().timeIntervalSince1970))"
        )
        context.insert(record)
        try? context.save()

        await MainActor.run {
            viewModel.debateStatus = "AI 멀티 에이전트 토론 준비 중..."
        }

        var transcript: [AgentTurn] = []
        do {

            // ── Round 1: Parallel per-persona analysis ───────────────────
            await withTaskGroup(of: AgentTurn.self) { group in
                for (role, pType) in zip(roles, personaTypes) {
                    let nodeSummary = personaSummaries[pType] ?? query
                    group.addTask {
                        do {
                            return try await self.callSpecialist(role, summary: nodeSummary,
                                                                  triggerContext: query)
                        } catch {
                            print("[Round1] \(role.rawValue) failed:", error)
                            return AgentTurn(agentID: role.rawValue, role: "analysis",
                                            domain: role.rawValue,
                                            content: "[\(role.domainLabel)] 분석을 완료하지 못했습니다.",
                                            confidence: 0.3, timestamp: Date())
                        }
                    }
                }
                for await turn in group {
                    transcript.append(turn)
                    let t = turn
                    await MainActor.run {
                        viewModel.liveDebateTurns.append(t)
                        viewModel.debateStatus = "\(t.domain) 분석 완료"
                    }
                    onTurnCompleted?(turn)
                }
            }

            // ── Round 2: Cross-domain rebuttals ───────────────────────────
            await MainActor.run { viewModel.debateStatus = "교차 반론 생성 중..." }
            let round1 = transcript
            for role in roles {
                let own   = round1.first { $0.agentID == role.rawValue }?.content ?? ""
                let other = round1.filter { $0.agentID != role.rawValue }
                                   .map { $0.content }.joined(separator: "\n---\n")
                let otherLabel = roles.filter { $0 != role }.map { $0.domainLabel }.joined(separator: ", ")
                guard !own.isEmpty, !other.isEmpty else { continue }
                do {
                    let rebuttal = try await callRebuttal(role, own: own, other: other, otherLabel: otherLabel)
                    transcript.append(rebuttal)
                    let r = rebuttal
                    await MainActor.run { viewModel.liveDebateTurns.append(r) }
                    onTurnCompleted?(rebuttal)
                } catch {
                    print("[Round2] \(role.rawValue) rebuttal failed:", error)
                }
            }

            // ── Round 3: Synthesis with game theory + consensus check ─────────
            await MainActor.run { viewModel.debateStatus = "최종 종합 분석 중..." }
            let fakeTrigger = DebateTrigger(
                primaryDomain:        roles.first.map { domainFromRole($0) } ?? .health,
                secondaryDomain:      roles.dropFirst().first.map { domainFromRole($0) } ?? .personal,
                evidenceNodeIDs:      [],
                patternDescription:   query,
                urgencyScore:         0.8,
                primaryDomainSummary: query,
                secondaryDomainSummary: "",
                personaID:            nil
            )
            let domainList = roles.map { $0.domainLabel }.joined(separator: " vs ")
            let compressed = "참여 에이전트 도메인: [\(domainList)]\n\n\(compressTranscript(transcript))"
            let synthesis: AgentTurn
            do {
                synthesis = try await synthesize(compressed: compressed, trigger: fakeTrigger, useHITL: true)
            } catch {
                print("[startManualDebate] synthesis failed, using local fallback:", error)
                synthesis = makeFallbackSynthesis(transcript: transcript)
            }
            transcript.append(synthesis)

            let transcriptData = (try? JSONEncoder().encode(transcript)) ?? Data()
            record.agentTranscriptJSON = transcriptData
            record.synthesisResult     = synthesis.content

            let parsed = parseSynthesisJSON(synthesis.content)

            // ── HITL check: pause for human input if no consensus ─────────────
            if parsed?.consensusReached == false,
               let questions = parsed?.reverseQuestions, !questions.isEmpty {
                record.status = "awaiting_human"
                try? context.save()
                pendingHITLTranscript = transcript

                let finalTranscript = transcript
                await MainActor.run {
                    viewModel.activeDebateResult      = synthesis.content
                    viewModel.activeDebateTranscript  = finalTranscript
                    viewModel.liveDebateTurns         = finalTranscript
                    viewModel.debateNeedsHumanInput   = true
                    viewModel.debateReverseQuestions  = questions
                    viewModel.debateStatus            = nil
                }
                return
            }

            record.status = "completed"
            try? context.save()

            let notifSummary = parsed?.rootCause ?? String(synthesis.content.prefix(100))
            await NotificationService.shared.sendDebateCompletionNotification(
                title: "멀티 에이전트 토론 완료",
                summary: notifSummary
            )

            let finalTranscript = transcript
            let synthesisTurn   = synthesis
            await MainActor.run {
                viewModel.liveDebateTurns.append(synthesisTurn)
                viewModel.activeDebateResult     = synthesis.content
                viewModel.activeDebateTranscript = finalTranscript
                viewModel.debateStatus           = nil
                viewModel.refreshFromSwiftData()
            }
        } catch {
            print("[startManualDebate] unexpected error:", error)
            record.status = "failed"
            try? context.save()
            // transcript is in scope here — always show something to the user
            let fallback = makeFallbackSynthesis(transcript: transcript)
            await MainActor.run {
                viewModel.activeDebateResult = fallback.content
                viewModel.debateStatus       = nil
            }
        }
    }

    // MARK: - HITL: Continue debate after human answers reverse questions

    func continueManualDebateWithAnswer(answer: String,
                                        context: ModelContext,
                                        viewModel: GraphViewModel) async {
        let transcript = pendingHITLTranscript
        guard !transcript.isEmpty else { return }

        await MainActor.run {
            viewModel.debateStatus            = "인간 피드백 반영 중..."
            viewModel.debateNeedsHumanInput   = false
        }

        do {
            let compressed = compressTranscript(transcript)
            let userMsg = """
            이전 토론 요약:
            \(compressed)

            인간의 답변:
            \(answer)

            위 답변을 반영하여 최종 결론을 도출하세요.
            """
            let synthesisText = try await callBestProvider(
                system: PromptStore.shared.prompt(for: .debateHumanContinue),
                userMessage: userMsg
            )

            let finalTurn = AgentTurn(agentID: "synthesizer", role: "synthesis",
                                      domain: "synthesizer", content: synthesisText,
                                      confidence: 1.0, timestamp: Date())
            var updatedTranscript = transcript
            updatedTranscript.append(finalTurn)

            // Finalize the "awaiting_human" record
            let allRecords = (try? context.fetch(FetchDescriptor<DebateRecord>())) ?? []
            if let pending = allRecords.first(where: { $0.status == "awaiting_human" }) {
                pending.synthesisResult     = synthesisText
                pending.agentTranscriptJSON = (try? JSONEncoder().encode(updatedTranscript)) ?? Data()
                pending.status              = "completed"
                try? context.save()
            }

            pendingHITLTranscript = []

            let parsed = parseSynthesisJSON(synthesisText)
            let notifSummary = parsed?.rootCause ?? String(synthesisText.prefix(100))
            await NotificationService.shared.sendDebateCompletionNotification(
                title: "멀티 에이전트 토론 완료",
                summary: notifSummary
            )

            let ft = updatedTranscript
            await MainActor.run {
                viewModel.activeDebateResult     = synthesisText
                viewModel.activeDebateTranscript = ft
                viewModel.liveDebateTurns.append(finalTurn)
                viewModel.debateReverseQuestions = []
                viewModel.debateHumanAnswer      = ""
                viewModel.debateStatus           = nil
                viewModel.refreshFromSwiftData()
            }
        } catch {
            await MainActor.run { viewModel.debateStatus = nil }
        }
    }

    // MARK: - Entry Point (automatic trigger)

    /// Start a multi-agent debate for the given trigger.
    /// Runs entirely in the background; UI updates go through MainActor.
    func startDebate(trigger: DebateTrigger,
                     context: ModelContext,
                     viewModel: GraphViewModel) async {
        let hash = await MainActor.run { trigger.debateHash }
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
                .health, own: healthTurn.content, other: workTurn.content, otherLabel: "업무"
            )
            let workRebuttal = try await callRebuttal(
                .work, own: workTurn.content, other: healthTurn.content, otherLabel: "건강"
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

            let notifSummary = parseSynthesisJSON(synthesis.content)?.rootCause
                ?? String(synthesis.content.prefix(100))
            await NotificationService.shared.sendDebateCompletionNotification(summary: notifSummary)

            let finalTranscript = transcript
            await MainActor.run {
                viewModel.activeDebateResult     = synthesis.content
                viewModel.activeDebateTranscript = finalTranscript
                viewModel.debateStatus           = nil
                viewModel.debateEvidenceNodeIDs  = []
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
        [당신의 역할: \(role.domainLabel) 전문가 에이전트]

        사용자 질문:
        \(triggerContext)

        당신의 페르소나에 축적된 노드 데이터:
        \(summary)

        위 노드 데이터를 바탕으로 사용자 질문과 관련된 패턴, 근본 원인, 가설을 분석하세요.
        """
        let content = try await callBestProvider(system: role.systemPrompt, userMessage: userMsg)
        let confidence = extractConfidence(from: content)
        return AgentTurn(agentID: role.rawValue, role: "analysis", domain: role.rawValue,
                         content: content, confidence: confidence, timestamp: Date())
    }

    // MARK: - Round 2: Rebuttals

    private func callRebuttal(_ role: SpecialistRole,
                               own: String,
                               other: String,
                               otherLabel: String? = nil) async throws -> AgentTurn {
        let opponentDesc = otherLabel.map { "[\($0) 전문가 에이전트] 분석" } ?? "상대 에이전트 분석"
        let userMsg = """
        [당신의 역할: \(role.domainLabel) 전문가 에이전트]

        내 1라운드 분석:
        \(String(own.prefix(700)))

        \(opponentDesc):
        \(String(other.prefix(700)))

        상대 분석에 대한 반론 또는 보완점을 제시하고, 인과관계 방향을 검토하세요.
        """
        let content = try await callBestProvider(system: role.rebuttalPrompt, userMessage: userMsg)
        let confidence = extractConfidence(from: content)
        return AgentTurn(agentID: "\(role.rawValue)-rebuttal", role: "rebuttal", domain: role.rawValue,
                         content: content, confidence: confidence, timestamp: Date())
    }

    // MARK: - Round 3: On-Device Synthesis (prefer Apple Intelligence for privacy)

    private func synthesize(compressed: String,
                             trigger: DebateTrigger,
                             useHITL: Bool = false) async throws -> AgentTurn {
        let apiPromptKey: PromptKey = useHITL ? .debateSynthesisHITLAPI : .debateSynthesisAPI
        let apiUserMsg = "토론 요약:\n\(String(compressed.prefix(2000)))\n\nJSON으로 종합 분석하세요."
        var synthesisText = ""

        // Attempt 1: Apple Intelligence structured generation
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            do {
                let applePromptKey: PromptKey = useHITL ? .debateSynthesisHITLApple : .debateSynthesisApple
                let session = LanguageModelSession(instructions: PromptStore.shared.prompt(for: applePromptKey))
                let response = try await session.respond(
                    to: "토론 요약:\n\(String(compressed.prefix(2000)))\n\n위 토론을 종합하여 핵심 원인과 행동 계획을 도출하세요.",
                    generating: DebateSynthesisResult.self
                )
                synthesisText = encodeToJSON(response.content)
            } catch {
                print("[Synthesis] Apple Intelligence failed:", error)
            }
        }

        // Attempt 2: API provider (if Apple Intelligence not used or failed)
        if synthesisText.isEmpty {
            do {
                synthesisText = try await callBestProvider(
                    system: PromptStore.shared.prompt(for: apiPromptKey),
                    userMessage: apiUserMsg
                )
            } catch {
                print("[Synthesis] API provider failed:", error)
            }
        }

        guard !synthesisText.isEmpty else { throw DebateError.synthesisEmpty }

        return AgentTurn(agentID: "synthesizer", role: "synthesis", domain: "synthesizer",
                         content: synthesisText, confidence: 1.0, timestamp: Date())
    }

    private func encodeToJSON(_ result: DebateSynthesisResult) -> String {
        let dict: [String: Any] = [
            "rootCause":        result.rootCause,
            "actions":          result.actions,
            "actionScores":     result.actionScores,
            "urgency":          result.urgency,
            "consensusReached": result.consensusReached,
            "reverseQuestions": result.reverseQuestions
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str  = String(data: data, encoding: .utf8) else {
            return "{\"rootCause\": \"\(result.rootCause)\", \"actions\": [], \"actionScores\": [], \"urgency\": \"soon\", \"consensusReached\": true, \"reverseQuestions\": []}"
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
        let provider = await MainActor.run { AIProviderManager.shared.selectedProvider }

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
        return try await AIProviderManager.shared.callAI(provider: provider,
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
        guard let data = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rootCause = dict["rootCause"] as? String,
              let actions   = dict["actions"]   as? [String],
              let urgency   = dict["urgency"]   as? String else { return nil }
        let actionScores     = dict["actionScores"]     as? [Double]  ?? []
        let consensusReached = dict["consensusReached"] as? Bool      ?? true
        let reverseQuestions = dict["reverseQuestions"] as? [String]  ?? []
        return SynthesisJSON(rootCause: rootCause, actions: actions,
                             actionScores: actionScores, urgency: urgency,
                             consensusReached: consensusReached,
                             reverseQuestions: reverseQuestions)
    }

    private func makeFallbackSynthesis(transcript: [AgentTurn]) -> AgentTurn {
        let analyses = transcript.filter { $0.role == "analysis" }
        let summary = analyses.map { "[\($0.domain)] \(String($0.content.prefix(120)))" }
                              .joined(separator: " / ")
        let escaped = summary
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "\n", with: " ")
        let json = """
        {"rootCause":"\(escaped)","actions":["각 페르소나 분석 내용 확인","페르소나별 추가 대화","우선순위 직접 결정"],"actionScores":[0.7,0.6,0.5],"urgency":"soon","consensusReached":true,"reverseQuestions":[]}
        """
        return AgentTurn(agentID: "synthesizer", role: "synthesis", domain: "synthesizer",
                         content: json, confidence: 0.4, timestamp: Date())
    }

    private func domainFromRole(_ role: SpecialistRole) -> DebateTrigger.Domain {
        switch role {
        case .health:   return .health
        case .work:     return .work
        case .finance:  return .finance
        case .academic: return .academic
        case .hobby:    return .personal
        }
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
