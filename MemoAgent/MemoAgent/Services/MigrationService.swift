// MigrationService.swift
// MemoAgent V2 — One-time migration from V1 UserDefaults → SwiftData

import Foundation
import SwiftData

enum MigrationService {
    private static let doneKey            = "memoagent.migration.v2.done"
    private static let personaV3DoneKey   = "memoagent.migration.v3.persona.done"
    private static let nodesKey = "memoagent.nodes.v1"
    private static let edgesKey = "memoagent.edges.v1"

    // ── V3 PersonaType rawValue migration ─────────────────────────────
    // "Medical" → "Health", "Personal" → "Hobby", "Work" → removed (maps to nil)
    private static let personaRawValueMap: [String: String] = [
        "Medical": "Health",
        "Personal": "Hobby",
    ]

    /// Migrates PersonaRecord.typeRaw values from V2 → V3 enum names.
    /// Removes PersonaRecords with typeRaw == "Work" (no direct V3 mapping).
    static func migratePersonaTypesIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: personaV3DoneKey) else { return }

        let descriptor = FetchDescriptor<PersonaRecord>()
        guard let records = try? context.fetch(descriptor) else { return }

        for record in records {
            if let mapped = personaRawValueMap[record.personaTypeRaw] {
                record.personaTypeRaw = mapped
            }
            // "Work" personas have no V3 equivalent — keep as-is (typeRaw stays "Work",
            // personaType computed property will return nil, and the app handles nil gracefully).
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: personaV3DoneKey)
            print("[MigrationService] V3 PersonaType migration complete.")
        } catch {
            print("[MigrationService] V3 PersonaType migration failed: \(error)")
        }
    }

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
