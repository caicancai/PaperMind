import SwiftUI

@main
struct PaperMindApp: App {
    @StateObject private var viewModel = AppViewModel(dependencies: .makeLive())

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .task {
                    await viewModel.bootstrap()
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
