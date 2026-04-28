// MemoAgentApp.swift
// MemoAgent V2

import SwiftUI
import SwiftData

@main
struct MemoAgentApp: App {
    @Environment(\.scenePhase) private var scenePhase

    // Static container — created once for the app lifetime.
    // Static access lets the @State initializer below reference it safely.
    private static let container: ModelContainer = {
        let schema = Schema([
            NodeRecord.self,
            EdgeRecord.self,
            PersonaRecord.self,
            DebateRecord.self,
            ChatSession.self,
            ChatMessage.self,
            FinanceEntry.self,
        ])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema changed (e.g. new personaIDs column) — wipe existing store and recreate.
            // Safe during development; replace with a VersionedSchema migration plan before shipping.
            let storeURL = config.url
            let fm = FileManager.default
            let base = storeURL.deletingPathExtension()
            for ext in ["store", "store-shm", "store-wal"] {
                try? fm.removeItem(at: base.appendingPathExtension(ext))
            }
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("SwiftData ModelContainer failed to initialize: \(error)")
            }
        }
    }()

    @State private var viewModel: GraphViewModel = {
        let ctx = MemoAgentApp.container.mainContext
        MigrationService.migratePersonaTypesIfNeeded(context: ctx)
        let vm = GraphViewModel(modelContext: ctx)
        Self.bootstrapDefaultProvider()
        return vm
    }()

    private static func bootstrapDefaultProvider() {
        let mgr = AIProviderManager.shared
        // Set OpenAI as default if not already chosen
        if UserDefaults.standard.string(forKey: "memoagent.ai.provider.v1") == nil {
            mgr.selectedProvider = .openAI
        }
        // Pre-populate keychain if key is missing
        if mgr.loadAPIKey(for: .openAI) == nil, !Secrets.openAIKey.isEmpty {
            mgr.saveAPIKey(Secrets.openAIKey, for: .openAI)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .environment(viewModel)
                .modelContainer(MemoAgentApp.container)
                // Request notification permission once at first launch
                .task { await NotificationService.shared.requestPermission() }
                // Persona onboarding — shown on first launch when no personas exist.
                .sheet(isPresented: Binding(
                    get: { viewModel.showingPersonaOnboarding },
                    set: { viewModel.showingPersonaOnboarding = $0 }
                )) {
                    PersonaOnboardingView()
                        .environment(viewModel)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 800)
        // Run scheduled daily analysis on every scene foreground activation
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.runScheduledAnalysis()
            }
        }
    }
}
