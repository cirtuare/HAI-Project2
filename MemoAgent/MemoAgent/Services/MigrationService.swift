// MigrationService.swift
// MemoAgent V2 — One-time migration from V1 UserDefaults → SwiftData

import Foundation
import SwiftData

enum MigrationService {
    private static let doneKey  = "memoagent.migration.v2.done"
    private static let nodesKey = "memoagent.nodes.v1"
    private static let edgesKey = "memoagent.edges.v1"

    /// Call once at app startup, before any SwiftData fetch.
    /// Safe to call multiple times — no-ops after first successful run.
    static func migrateIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }

        let decoder = JSONDecoder()

        // ── Nodes ─────────────────────────────────────────────────────
        var migratedCount = 0
        if let data = UserDefaults.standard.data(forKey: nodesKey),
           let v1Nodes = try? decoder.decode([GraphNode].self, from: data) {
            for node in v1Nodes {
                let record = NodeRecord.from(node, schemaVersion: 1)
                context.insert(record)
                migratedCount += 1
            }
        }

        // ── Edges ─────────────────────────────────────────────────────
        if let data = UserDefaults.standard.data(forKey: edgesKey),
           let v1Edges = try? decoder.decode([GraphEdge].self, from: data) {
            for edge in v1Edges {
                context.insert(EdgeRecord.from(edge))
            }
        }

        // ── Commit ────────────────────────────────────────────────────
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: doneKey)
            if migratedCount > 0 {
                print("[MigrationService] Migrated \(migratedCount) V1 nodes to SwiftData.")
            }
        } catch {
            // Migration failed — will retry next launch (doneKey not set).
            print("[MigrationService] Migration failed: \(error). Will retry on next launch.")
        }
    }
}
