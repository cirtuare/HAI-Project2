// NodeRecord.swift
// MemoAgent V2 — SwiftData persistent model for graph nodes
// Adapter pattern: views still use GraphNode struct; this is the DB layer.

import Foundation
import SwiftData
import CoreGraphics

@Model
final class NodeRecord {
    @Attribute(.unique) var id: String
    var title: String
    var summary: String
    var nodeTypeRaw: String
    var date: String
    var originalText: String
    var isImportant: Bool
    var tags: [String]
    var positionX: Double
    var positionY: Double
    // V2 additions
    var sourceSystemRaw: String
    var externalID: String?    // PHAsset.localIdentifier, EKEvent.eventIdentifier, etc.
    var personaID: String?     // nil = visible to all personas
    var schemaVersion: Int     // 1 = migrated from V1, 2 = native V2
    var isProcessed: Bool      // false = pending NodeManagerAgent analysis
    var createdAt: Date

    init(id: String = UUID().uuidString,
         title: String,
         summary: String,
         nodeTypeRaw: String,
         date: String,
         originalText: String,
         isImportant: Bool,
         tags: [String],
         positionX: Double,
         positionY: Double,
         sourceSystemRaw: String = SourceSystem.userCreated.rawValue,
         externalID: String? = nil,
         personaID: String? = nil,
         schemaVersion: Int = 2,
         isProcessed: Bool = true,
         createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.summary = summary
        self.nodeTypeRaw = nodeTypeRaw
        self.date = date
        self.originalText = originalText
        self.isImportant = isImportant
        self.tags = tags
        self.positionX = positionX
        self.positionY = positionY
        self.sourceSystemRaw = sourceSystemRaw
        self.externalID = externalID
        self.personaID = personaID
        self.schemaVersion = schemaVersion
        self.isProcessed = isProcessed
        self.createdAt = createdAt
    }

    // MARK: - Conversion

    func toGraphNode() -> GraphNode {
        GraphNode(
            id: id,
            title: title,
            summary: summary,
            type: NodeType(rawValue: nodeTypeRaw) ?? .memo,
            date: date,
            originalText: originalText,
            isImportant: isImportant,
            tags: tags,
            position: CGPoint(x: positionX, y: positionY),
            sourceSystem: SourceSystem(rawValue: sourceSystemRaw) ?? .userCreated,
            externalID: externalID,
            personaID: personaID
        )
    }

    func update(from node: GraphNode) {
        title          = node.title
        summary        = node.summary
        nodeTypeRaw    = node.type.rawValue
        date           = node.date
        originalText   = node.originalText
        isImportant    = node.isImportant
        tags           = node.tags
        positionX      = node.position.x
        positionY      = node.position.y
        sourceSystemRaw = node.sourceSystem.rawValue
        externalID     = node.externalID
        personaID      = node.personaID
    }

    static func from(_ node: GraphNode, schemaVersion: Int = 2) -> NodeRecord {
        NodeRecord(
            id: node.id,
            title: node.title,
            summary: node.summary,
            nodeTypeRaw: node.type.rawValue,
            date: node.date,
            originalText: node.originalText,
            isImportant: node.isImportant,
            tags: node.tags,
            positionX: node.position.x,
            positionY: node.position.y,
            sourceSystemRaw: node.sourceSystem.rawValue,
            externalID: node.externalID,
            personaID: node.personaID,
            schemaVersion: schemaVersion
        )
    }
}
