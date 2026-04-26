// EcosystemSyncService.swift
// MemoAgent V2 — Apple ecosystem sync orchestrator
//
// Runs as a Swift actor to prevent data races from concurrent sync operations.
// Each sync operation collects nodes and pushes them to GraphViewModel.

import Foundation
import SwiftData

// MARK: - EcosystemSyncService

actor EcosystemSyncService {
    static let shared = EcosystemSyncService()
    private init() {}

    // MARK: - Full Sync

    /// Sync all enabled Apple framework sources for the given persona.
    /// Calls back to GraphViewModel on the main actor when new nodes are ready.
    func syncAll(persona: PersonaRecord, viewModel: GraphViewModel) async {
        // Calendar and Reminders can run in parallel via async let
        async let calendarFetch: [GraphNode] = EventKitSyncProvider.shared.fetchCalendarNodes(for: persona)
        async let reminderFetch: [GraphNode] = EventKitSyncProvider.shared.fetchReminderNodes(for: persona)
        async let healthFetch: [GraphNode]   = HealthKitSyncProvider.shared.fetchNodes(for: persona)

        var allNodes = await calendarFetch + (await reminderFetch) + (await healthFetch)

        // Photos are heavier — run after the lighter sources
        let photoNodes = await PhotoKitSyncProvider.shared.fetchRecentPhotoNodes(for: persona, limit: 20)
        allNodes.append(contentsOf: photoNodes)

        guard !allNodes.isEmpty else { return }

        // Capture as let so MainActor.run doesn't reference a captured var
        let finalNodes = allNodes
        await MainActor.run {
            viewModel.insertEcosystemNodes(finalNodes)
            viewModel.isSyncing = false
        }
    }

    // MARK: - Per-Source Sync

    func syncCalendar(persona: PersonaRecord, viewModel: GraphViewModel) async {
        let nodes = await EventKitSyncProvider.shared.fetchCalendarNodes(for: persona)
        await MainActor.run { viewModel.insertEcosystemNodes(nodes) }
    }

    func syncReminders(persona: PersonaRecord, viewModel: GraphViewModel) async {
        let nodes = await EventKitSyncProvider.shared.fetchReminderNodes(for: persona)
        await MainActor.run { viewModel.insertEcosystemNodes(nodes) }
    }

    func syncHealth(persona: PersonaRecord, viewModel: GraphViewModel) async {
        let nodes = await HealthKitSyncProvider.shared.fetchNodes(for: persona)
        await MainActor.run { viewModel.insertEcosystemNodes(nodes) }
    }

    func syncPhotos(persona: PersonaRecord, viewModel: GraphViewModel) async {
        let nodes = await PhotoKitSyncProvider.shared.fetchRecentPhotoNodes(for: persona, limit: 20)
        await MainActor.run { viewModel.insertEcosystemNodes(nodes) }
    }

    /// Parse a pasted Screen Time report and insert nodes for the health persona.
    func syncScreenTime(
        reportText: String,
        persona: PersonaRecord,
        viewModel: GraphViewModel,
        context: ModelContext
    ) async {
        let (total, categories) = await ScreenTimeSyncProvider.shared.parse(reportText)
        let nodes = await ScreenTimeSyncProvider.shared.createNodes(
            reportText: reportText,
            total: total,
            categories: categories,
            persona: persona
        )
        await ScreenTimeSyncProvider.shared.save(nodes: nodes, context: context, viewModel: viewModel)
    }

    /// Parse a pasted finance statement and insert entries + nodes for the finance persona.
    func syncFinance(
        statementText: String,
        source: FinanceEntrySource = .text,
        persona: PersonaRecord,
        viewModel: GraphViewModel,
        context: ModelContext
    ) async -> Int {
        let entries = await FinanceSyncProvider.shared.parse(statementText, source: source)
        let nodes = await FinanceSyncProvider.shared.createNodes(
            entries: entries,
            rawText: statementText,
            persona: persona
        )
        await FinanceSyncProvider.shared.save(
            entries: entries,
            nodes: nodes,
            context: context,
            viewModel: viewModel
        )
        return entries.count
    }
}

// MARK: - GraphViewModel Convenience Extension

extension GraphViewModel {
    /// Trigger a full ecosystem sync for the active persona.
    /// After sync completes, automatically runs cross-domain pattern detection
    /// which may start a multi-agent debate if urgency threshold is met.
    @MainActor
    func triggerEcosystemSync() {
        guard let persona = activePersona else { return }
        isSyncing = true
        Task {
            await EcosystemSyncService.shared.syncAll(persona: persona, viewModel: self)
            // Pattern detection uses the ViewModel's internal modelContext
            self.runDebatePatternDetection()
        }
    }
}
