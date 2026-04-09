// EcosystemSyncService.swift
// MemoAgent V2 — Apple ecosystem sync orchestrator
//
// Runs as a Swift actor to prevent data races from concurrent sync operations.
// Each sync operation collects nodes and pushes them to GraphViewModel.

import Foundation

// MARK: - EcosystemSyncService

actor EcosystemSyncService {
    static let shared = EcosystemSyncService()
    private init() {}

    // MARK: - Full Sync

    /// Sync all enabled Apple framework sources for the given persona.
    /// Calls back to GraphViewModel on the main actor when new nodes are ready.
    func syncAll(persona: PersonaRecord, viewModel: GraphViewModel) async {
        var allNodes: [GraphNode] = []

        // Calendar and Reminders can run in parallel with each other
        async let calendarTask = Task {
            EventKitSyncProvider.shared.fetchCalendarNodes(for: persona)
        }
        async let reminderTask = Task {
            await EventKitSyncProvider.shared.fetchReminderNodes(for: persona)
        }
        async let healthTask = Task {
            await HealthKitSyncProvider.shared.fetchNodes(for: persona)
        }

        let calendarNodes  = await calendarTask.value
        let reminderNodes  = await reminderTask.value
        let healthNodes    = await healthTask.value

        allNodes.append(contentsOf: calendarNodes)
        allNodes.append(contentsOf: reminderNodes)
        allNodes.append(contentsOf: healthNodes)

        // Photos are heavier — run after the lighter sources
        let photoNodes = PhotoKitSyncProvider.shared.fetchRecentPhotoNodes(for: persona, limit: 20)
        allNodes.append(contentsOf: photoNodes)

        guard !allNodes.isEmpty else { return }

        await MainActor.run {
            viewModel.insertEcosystemNodes(allNodes)
            viewModel.isSyncing = false
        }
    }

    // MARK: - Per-Source Sync

    func syncCalendar(persona: PersonaRecord, viewModel: GraphViewModel) async {
        let nodes = EventKitSyncProvider.shared.fetchCalendarNodes(for: persona)
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
        let nodes = PhotoKitSyncProvider.shared.fetchRecentPhotoNodes(for: persona, limit: 20)
        await MainActor.run { viewModel.insertEcosystemNodes(nodes) }
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
