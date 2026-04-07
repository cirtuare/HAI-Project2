// GraphEdge.swift
// MemoAgent — Phase 1: Core Data Models
//
// Pure Swift struct. Zero SwiftUI dependencies.

import Foundation

// MARK: - EdgeStyle

/// Visual style flags for an edge, mirroring the React Flow `style` object
/// and the `animated` / `strokeDasharray` properties used in sampleNodes.ts.
struct EdgeStyle: Hashable, Codable {
    /// Line width in canvas points.
    var strokeWidth: Double
    /// When true the edge renders with a flowing dash animation.
    var animated: Bool
    /// When true the edge was manually created by the user (dashed line style).
    var isUserCreated: Bool

    static let `default` = EdgeStyle(strokeWidth: 2, animated: false, isUserCreated: false)
}

// MARK: - GraphEdge

/// A directed connection between two `GraphNode` instances.
/// Mirrors the React Flow `Edge` type.
struct GraphEdge: Identifiable, Hashable, Codable {
    let id: String
    var sourceID: String
    var targetID: String
    var style: EdgeStyle

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GraphEdge, rhs: GraphEdge) -> Bool {
        lhs.id == rhs.id
    }
}
