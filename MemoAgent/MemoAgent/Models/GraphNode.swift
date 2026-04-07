// GraphNode.swift
// MemoAgent — Phase 1: Core Data Models
//
// Pure Swift structs with zero SwiftUI dependencies.
// Conforms to Identifiable, Hashable, and Codable as required.

import Foundation

// MARK: - NodeType

/// The category of a knowledge node, mirroring the React `NodeType` union.
enum NodeType: String, CaseIterable, Codable, Hashable {
    case memo
    case pdf
    case diary
    case chat

    /// Human-readable Korean label used in the sidebar filter UI.
    var localizedLabel: String {
        switch self {
        case .memo:  return "메모"
        case .pdf:   return "PDF 문서"
        case .diary: return "일기/저널"
        case .chat:  return "AI 대화"
        }
    }

    /// Accent color hex string (dark-mode optimised, matching React typeConfig).
    var hexColor: String {
        switch self {
        case .memo:  return "#06b6d4"   // cyan-500
        case .pdf:   return "#f43f5e"   // rose-500
        case .diary: return "#f59e0b"   // amber-500
        case .chat:  return "#8b5cf6"   // violet-500
        }
    }

    /// SF Symbol name that replaces the lucide-react icon.
    var systemImage: String {
        switch self {
        case .memo:  return "doc.text"
        case .pdf:   return "doc.fill"
        case .diary: return "book.closed"
        case .chat:  return "message"
        }
    }
}

// MARK: - GraphNode

/// A single knowledge node in the graph.
/// Mirrors the `NodeData` interface and the React Flow `Node<NodeData>` shape.
struct GraphNode: Identifiable, Hashable, Codable {
    // MARK: Identity
    let id: String

    // MARK: Display data (from NodeData)
    var title: String
    var summary: String
    var type: NodeType
    var date: String
    var originalText: String
    var isImportant: Bool
    var tags: [String]

    // MARK: Canvas position
    /// The node's position on the infinite canvas in canvas-space coordinates.
    /// Mirrors `position: { x, y }` from React Flow.
    var position: CGPoint

    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
        lhs.id == rhs.id
    }
}

// CGPoint already conforms to Codable via CoreGraphics on macOS 14+.
