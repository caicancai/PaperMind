import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            LibraryView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } content: {
            ReaderPaneView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 840, ideal: 980)
        } detail: {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1380, minHeight: 820)
    }
}
