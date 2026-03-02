import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            NavigationSplitView {
                LibraryView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 300)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } content: {
                ReaderPaneView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 560, ideal: 760)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } detail: {
                SidebarView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 340, max: 440)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .navigationSplitViewStyle(.balanced)
            .padding(12)
        }
        .frame(minWidth: 1080, minHeight: 760)
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme {
        switch viewModel.appTheme {
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var backgroundGradientColors: [Color] {
        switch viewModel.appTheme {
        case .light:
            return [
                Color(red: 0.96, green: 0.98, blue: 1.00),
                Color(red: 0.96, green: 0.97, blue: 0.95)
            ]
        case .dark:
            return [
                Color(red: 0.12, green: 0.13, blue: 0.15),
                Color(red: 0.09, green: 0.10, blue: 0.12)
            ]
        }
    }
}
