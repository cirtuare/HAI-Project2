//
//  MemoAgentApp.swift
//  MemoAgent
//
//  Created by 이수민 on 4/7/26.
//

import SwiftUI

@main
struct MemoAgentApp: App {
    /// Single shared ViewModel instance for the whole app.
    @State private var viewModel = GraphViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 800)
    }
}
