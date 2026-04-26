// ChatRecord.swift
// MemoAgent — Phase 1: Chat data models
//
// ChatSession: a single conversation thread (one or more personas).
// ChatMessage: a single message within a session.

import Foundation
import SwiftData

// MARK: - ChatSession

@Model
final class ChatSession {
    @Attribute(.unique) var id: String
    var title: String
    /// PersonaType rawValues for the personas participating in this session.
    var selectedPersonaTypeRaws: [String]
    var createdAt: Date
    /// Optional link to a DebateRecord that was triggered from this session.
    var linkedDebateRecordID: String?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(
        id: String = UUID().uuidString,
        title: String = "",
        selectedPersonaTypeRaws: [String] = [],
        createdAt: Date = Date(),
        linkedDebateRecordID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.selectedPersonaTypeRaws = selectedPersonaTypeRaws
        self.createdAt = createdAt
        self.linkedDebateRecordID = linkedDebateRecordID
    }

    var selectedPersonaTypes: [PersonaType] {
        selectedPersonaTypeRaws.compactMap { PersonaType(rawValue: $0) }
    }
}

// MARK: - ChatMessage

@Model
final class ChatMessage {
    @Attribute(.unique) var id: String
    var role: String          // "user" | "persona" | "system"
    var personaTypeRaw: String?
    var content: String
    var timestamp: Date

    var session: ChatSession?

    init(
        id: String = UUID().uuidString,
        role: String,
        personaTypeRaw: String? = nil,
        content: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.personaTypeRaw = personaTypeRaw
        self.content = content
        self.timestamp = timestamp
    }

    var personaType: PersonaType? {
        guard let raw = personaTypeRaw else { return nil }
        return PersonaType(rawValue: raw)
    }
}

// MARK: - ChatRole constants

enum ChatRole {
    static let user    = "user"
    static let persona = "persona"
    static let system  = "system"
}
