// PersonaRecord.swift
// MemoAgent V2 — SwiftData model for user personas

import Foundation
import SwiftData

@Model
final class PersonaRecord {
    @Attribute(.unique) var id: String
    var name: String
    var personaTypeRaw: String
    var systemPromptContext: String
    var accentColorHex: String
    var isActive: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString,
         name: String,
         personaTypeRaw: String,
         systemPromptContext: String,
         accentColorHex: String,
         isActive: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.personaTypeRaw = personaTypeRaw
        self.systemPromptContext = systemPromptContext
        self.accentColorHex = accentColorHex
        self.isActive = isActive
        self.createdAt = createdAt
    }

    // MARK: - Convenience factory

    static func make(from type: PersonaType, isActive: Bool = false) -> PersonaRecord {
        PersonaRecord(
            name: type.localizedName,
            personaTypeRaw: type.rawValue,
            systemPromptContext: type.systemPromptContext,
            accentColorHex: type.accentHex,
            isActive: isActive
        )
    }

    var personaType: PersonaType? {
        PersonaType(rawValue: personaTypeRaw)
    }
}
