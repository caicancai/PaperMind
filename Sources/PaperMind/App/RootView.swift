import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.98, blue: 1.00),
                    Color(red: 0.96, green: 0.97, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationSplitView {
                LibraryView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 320)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } content: {
                ReaderPaneView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 880, ideal: 1020)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } detail: {
                SidebarView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 340, ideal: 390, max: 460)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .navigationSplitViewStyle(.balanced)
            .padding(12)
        }
        .frame(minWidth: 1380, minHeight: 820)
    }
}
