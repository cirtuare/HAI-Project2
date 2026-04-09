// DebateRecord.swift
// MemoAgent V2 — Multi-Agent Debate System: Data models

import Foundation
import SwiftData

// MARK: - AgentTurn

struct AgentTurn: Codable {
    let agentID: String
    let role: String       // "analysis" | "rebuttal" | "synthesis"
    let domain: String     // "health" | "work" | "synthesizer"
    let content: String
    let confidence: Double
    let timestamp: Date
}

// MARK: - DebateTrigger

struct DebateTrigger {
    enum Domain: String {
        case health, work, finance, academic, personal
    }

    let primaryDomain: Domain
    let secondaryDomain: Domain
    let evidenceNodeIDs: [String]      // NodeRecord IDs
    let patternDescription: String
    let urgencyScore: Double           // 0–1; debate fires when >= 0.6
    /// Pre-digested summaries sent to external APIs — no raw PII
    let primaryDomainSummary: String
    let secondaryDomainSummary: String
    let personaID: String?

    /// Stable key used for 24-hour deduplication
    var debateHash: String {
        let day = ISO8601DateFormatter().string(from: Date()).prefix(10)
        return "\(primaryDomain.rawValue)-\(secondaryDomain.rawValue)-\(day)"
    }
}

// MARK: - DebateRecord (@Model)

@Model
final class DebateRecord {
    @Attribute(.unique) var id: String
    var triggerDescription: String
    var agentTranscriptJSON: Data       // [AgentTurn] encoded
    var synthesisResult: String
    var actionNodeIDs: [String]         // NodeRecord IDs created by ActionPlanBuilder
    var status: String                  // "running" | "completed" | "failed"
    var createdAt: Date
    var personaID: String?
    var debateHash: String?             // used for 24h deduplication

    init(id: String = UUID().uuidString,
         triggerDescription: String,
         agentTranscriptJSON: Data = Data(),
         synthesisResult: String = "",
         actionNodeIDs: [String] = [],
         status: String = "running",
         createdAt: Date = Date(),
         personaID: String? = nil,
         debateHash: String? = nil) {
        self.id = id
        self.triggerDescription = triggerDescription
        self.agentTranscriptJSON = agentTranscriptJSON
        self.synthesisResult = synthesisResult
        self.actionNodeIDs = actionNodeIDs
        self.status = status
        self.createdAt = createdAt
        self.personaID = personaID
        self.debateHash = debateHash
    }
}
