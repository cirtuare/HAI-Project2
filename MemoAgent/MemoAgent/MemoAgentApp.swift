// MemoAgentApp.swift
// MemoAgent V2

import SwiftUI
import SwiftData

@main
struct MemoAgentApp: App {

    // Static container — created once for the app lifetime.
    // Static access lets the @State initializer below reference it safely.
    private static let container: ModelContainer = {
        let schema = Schema([NodeRecord.self, EdgeRecord.self, PersonaRecord.self, DebateRecord.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("SwiftData ModelContainer failed to initialize: \(error)")
        }
    }()

    @State private var viewModel = GraphViewModel(modelContext: MemoAgentApp.container.mainContext)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .modelContainer(MemoAgentApp.container)
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
    }
}
