// ContentView.swift
// MemoAgent — Phase 4: Complete App Shell
//
// NavigationSplitView wires together:
//  - LeftSidebarView  (navigation + filters)
//  - GraphCanvasView  (full interactive engine)
//  - DetailInspectorView inside .inspector()
//  - SmartInputModalView as a .sheet

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(GraphViewModel.self) private var vm

    @ViewBuilder
    private var mainContent: some View {
        switch vm.activeViewMode {
        case .context:
            GraphCanvasView()
        case .origin:
            OriginView()
        case .timeline:
            NodeTimelineView()
        }
    }

    var body: some View {
        NavigationSplitView {
            LeftSidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            mainContent
                .inspector(isPresented: Binding(
                    get: { vm.isInspectorPresented },
                    set: { vm.isInspectorPresented = $0 }
                )) {
                    DetailInspectorView()
                        .inspectorColumnWidth(min: 300, ideal: 360, max: 420)
                }
        }
        .toolbar {
            NodeMindToolbar()
        }
        // SmartInput modal — presented as a borderless floating sheet
        .sheet(isPresented: Binding(
            get: { vm.isAddModalPresented },
            set: { if !$0 { vm.isAddModalPresented = false } }
        )) {
            SmartInputModalView()
                .environment(vm)
        }
        // AI Settings sheet
        .sheet(isPresented: Binding(
            get: { vm.isSettingsPresented },
            set: { vm.isSettingsPresented = $0 }
        )) {
            SettingsView()
        }
        // Multi-Persona Chat sheet
        .sheet(isPresented: Binding(
            get: { vm.isChatPresented },
            set: { if !$0 { vm.closeChat() } }
        )) {
            MultiPersonaChatView()
                .environment(vm)
        }
        // Single-Persona Chat sheet
        .sheet(isPresented: Binding(
            get: { vm.isSingleChatPresented },
            set: { if !$0 { vm.closeSingleChat() } }
        )) {
            SinglePersonaChatView()
                .environment(vm)
        }
        // Live Debate visualization sheet
        .sheet(isPresented: Binding(
            get: { vm.isLiveDebatePresented },
            set: { vm.isLiveDebatePresented = $0 }
        )) {
            LiveDebateView()
                .environment(vm)
        }
        // Debate result panel — slides in from bottom-right when synthesis completes
        .overlay(alignment: .bottomTrailing) {
            if vm.activeDebateResult != nil {
                DebateResultPanel(onDismiss: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        vm.activeDebateResult = nil
                    }
                })
                .padding(.bottom, 20)
                .padding(.trailing, 20)
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.85),
                           value: vm.activeDebateResult != nil)
                .zIndex(30)
            }
        }
        // Escape key clears selection (also handled by modal's own .keyboardShortcut)
        .onKeyPress(.escape) {
            if !vm.isAddModalPresented {
                vm.clearSelection()
                return .handled
            }
            return .ignored
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: NodeRecord.self, EdgeRecord.self, PersonaRecord.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    ContentView()
        .environment(GraphViewModel(modelContext: container.mainContext))
        .modelContainer(container)
}
