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
    @State private var windowSize: CGSize = CGSize(width: 1200, height: 800)

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
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { windowSize = geo.size }
                    .onChange(of: geo.size) { _, new in windowSize = new }
            }
        )
        .toolbar {
            NodeMindToolbar()
        }
        // AI Settings sheet (system sheet — settings doesn't need tap-to-dismiss)
        .sheet(isPresented: Binding(
            get: { vm.isSettingsPresented },
            set: { vm.isSettingsPresented = $0 }
        )) {
            SettingsView()
                .frame(maxWidth: windowSize.width * 0.92)
        }
        // Tap-to-dismiss overlay modals
        .overlay {
            if vm.isAddModalPresented || vm.isChatPresented || vm.isSingleChatPresented || vm.isLiveDebatePresented {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if vm.isAddModalPresented { vm.isAddModalPresented = false }
                            if vm.isChatPresented { vm.closeChat() }
                            if vm.isSingleChatPresented { vm.closeSingleChat() }
                            if vm.isLiveDebatePresented { vm.isLiveDebatePresented = false }
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: vm.isAddModalPresented)
            }
        }
        .overlay {
            if vm.isAddModalPresented {
                SmartInputModalView(availableWidth: windowSize.width * 0.92)
                    .environment(vm)
                    .frame(maxWidth: windowSize.width * 0.92, maxHeight: windowSize.height * 0.88)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.isAddModalPresented)
            }
        }
        .overlay {
            if vm.isChatPresented {
                MultiPersonaChatView(availableWidth: windowSize.width * 0.92)
                    .environment(vm)
                    .frame(maxWidth: windowSize.width * 0.92, maxHeight: windowSize.height * 0.88)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.isChatPresented)
            }
        }
        .overlay {
            if vm.isSingleChatPresented {
                SinglePersonaChatView()
                    .environment(vm)
                    .frame(maxWidth: windowSize.width * 0.92, maxHeight: windowSize.height * 0.88)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.isSingleChatPresented)
            }
        }
        .overlay {
            if vm.isLiveDebatePresented {
                LiveDebateView()
                    .environment(vm)
                    .frame(maxWidth: windowSize.width * 0.92, maxHeight: windowSize.height * 0.88)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: vm.isLiveDebatePresented)
            }
        }
        // Debate result panel — slides in from bottom-right when synthesis completes
        .overlay(alignment: .bottomTrailing) {
            if vm.activeDebateResult != nil {
                DebateResultPanel(onDismiss: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        vm.activeDebateResult = nil
                        vm.isLiveDebatePresented = false
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
