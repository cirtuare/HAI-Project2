// EdgeRecord.swift
// MemoAgent V2 — SwiftData persistent model for graph edges

import Foundation
import SwiftData

@Model
final class EdgeRecord {
    @Attribute(.unique) var id: String
    var sourceID: String
    var targetID: String
    var relationship: String
    var strokeWidth: Double
    var isAnimated: Bool
    var isUserCreated: Bool
    var createdAt: Date

    init(id: String = UUID().uuidString,
         sourceID: String,
         targetID: String,
         relationship: String = "",
         strokeWidth: Double = 2,
         isAnimated: Bool = false,
         isUserCreated: Bool = false,
         createdAt: Date = Date()) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.relationship = relationship
        self.strokeWidth = strokeWidth
        self.isAnimated = isAnimated
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
    }

    // MARK: - Conversion

    func toGraphEdge() -> GraphEdge {
        GraphEdge(
            id: id,
            sourceID: sourceID,
            targetID: targetID,
            relationship: relationship,
            style: EdgeStyle(
                strokeWidth: strokeWidth,
                animated: isAnimated,
                isUserCreated: isUserCreated
            )
        )
    }

    func update(from edge: GraphEdge) {
        sourceID      = edge.sourceID
        targetID      = edge.targetID
        relationship  = edge.relationship
        strokeWidth   = edge.style.strokeWidth
        isAnimated    = edge.style.animated
        isUserCreated = edge.style.isUserCreated
    }

    static func from(_ edge: GraphEdge) -> EdgeRecord {
        EdgeRecord(
            id: edge.id,
            sourceID: edge.sourceID,
            targetID: edge.targetID,
            relationship: edge.relationship,
            strokeWidth: edge.style.strokeWidth,
            isAnimated: edge.style.animated,
            isUserCreated: edge.style.isUserCreated
        )
    }
}
