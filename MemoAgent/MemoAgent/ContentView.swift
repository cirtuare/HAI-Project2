// ContentView.swift
// MemoAgent — Phase 4: Complete App Shell
//
// NavigationSplitView wires together:
//  - LeftSidebarView  (navigation + filters)
//  - GraphCanvasView  (full interactive engine)
//  - DetailInspectorView inside .inspector()
//  - SmartInputModalView as a .sheet

import SwiftUI

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
    ContentView()
        .environment(GraphViewModel())
}
