// GraphNode.swift
// MemoAgent — Phase 1: Core Data Models
//
// Pure Swift structs with zero SwiftUI dependencies.
// Conforms to Identifiable, Hashable, and Codable as required.

import Foundation

// MARK: - NodeType

/// The category of a knowledge node.
enum NodeType: String, CaseIterable, Codable, Hashable {
    // V1 — raw values unchanged for Codable backward compatibility
    case memo
    case pdf
    case diary
    case chat
    // V2 — Apple ecosystem sources
    case healthMetric    = "healthMetric"
    case calendarEvent   = "calendarEvent"
    case photo           = "photo"
    case reminder        = "reminder"
    // V2 — AI-generated
    case aiCluster       = "aiCluster"

    /// Human-readable Korean label used in the sidebar filter UI.
    var localizedLabel: String {
        switch self {
        case .memo:          return "메모"
        case .pdf:           return "PDF 문서"
        case .diary:         return "일기/저널"
        case .chat:          return "AI 대화"
        case .healthMetric:  return "건강 데이터"
        case .calendarEvent: return "캘린더 이벤트"
        case .photo:         return "사진"
        case .reminder:      return "미리 알림"
        case .aiCluster:     return "AI 클러스터"
        }
    }

    /// Accent color hex string (dark-mode optimised).
    var hexColor: String {
        switch self {
        case .memo:          return "#06b6d4"   // cyan-500
        case .pdf:           return "#f43f5e"   // rose-500
        case .diary:         return "#f59e0b"   // amber-500
        case .chat:          return "#8b5cf6"   // violet-500
        case .healthMetric:  return "#f43f5e"   // rose-500
        case .calendarEvent: return "#3b82f6"   // blue-500
        case .photo:         return "#a855f7"   // purple-500
        case .reminder:      return "#22c55e"   // green-500
        case .aiCluster:     return "#f97316"   // orange-500
        }
    }

    /// SF Symbol name.
    var systemImage: String {
        switch self {
        case .memo:          return "doc.text"
        case .pdf:           return "doc.fill"
        case .diary:         return "book.closed"
        case .chat:          return "message"
        case .healthMetric:  return "heart.fill"
        case .calendarEvent: return "calendar"
        case .photo:         return "photo.fill"
        case .reminder:      return "checklist"
        case .aiCluster:     return "sparkles"
        }
    }

    /// V1 types only — used to determine whether to show this type in legacy filter modes.
    var isV1Type: Bool {
        switch self {
        case .memo, .pdf, .diary, .chat: return true
        default: return false
        }
    }
}

// MARK: - GraphNode

/// A single knowledge node in the graph (view-layer DTO).
/// Views use this struct; SwiftData persistence uses NodeRecord.
struct GraphNode: Identifiable, Hashable, Codable {
    // MARK: Identity
    let id: String

    // MARK: Display data
    var title: String
    var summary: String
    var type: NodeType
    var date: String
    var originalText: String
    var isImportant: Bool
    var tags: [String]

    // MARK: Canvas position
    var position: CGPoint

    // MARK: V2 extensions (default values preserve V1 Codable compatibility)
    var sourceSystem: SourceSystem
    var externalID: String?    // Apple system record ID (for deduplication)
    var personaID: String?     // nil = visible to all personas

    // MARK: - Init (V1 callers unchanged — new fields have defaults)
    init(id: String,
         title: String,
         summary: String,
         type: NodeType,
         date: String,
         originalText: String,
         isImportant: Bool,
         tags: [String],
         position: CGPoint,
         sourceSystem: SourceSystem = .userCreated,
         externalID: String? = nil,
         personaID: String? = nil) {
        self.id = id
        self.title = title
        self.summary = summary
        self.type = type
        self.date = date
        self.originalText = originalText
        self.isImportant = isImportant
        self.tags = tags
        self.position = position
        self.sourceSystem = sourceSystem
        self.externalID = externalID
        self.personaID = personaID
    }

    // MARK: - Codable (custom — decodeIfPresent for V2 fields so V1 JSON still loads)
    enum CodingKeys: String, CodingKey {
        case id, title, summary, type, date, originalText, isImportant, tags, position
        case sourceSystem, externalID, personaID
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self,    forKey: .id)
        title       = try c.decode(String.self,    forKey: .title)
        summary     = try c.decode(String.self,    forKey: .summary)
        type        = try c.decode(NodeType.self,  forKey: .type)
        date        = try c.decode(String.self,    forKey: .date)
        originalText = try c.decode(String.self,   forKey: .originalText)
        isImportant = try c.decode(Bool.self,      forKey: .isImportant)
        tags        = try c.decode([String].self,  forKey: .tags)
        position    = try c.decode(CGPoint.self,   forKey: .position)
        // V2 fields — default-to-nil/userCreated when loading old V1 JSON
        sourceSystem = try c.decodeIfPresent(SourceSystem.self, forKey: .sourceSystem) ?? .userCreated
        externalID  = try c.decodeIfPresent(String.self, forKey: .externalID)
        personaID   = try c.decodeIfPresent(String.self, forKey: .personaID)
    }

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool { lhs.id == rhs.id }
}

// CGPoint already conforms to Codable via CoreGraphics on macOS 14+.
