import SwiftUI
import AppKit

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HSplitView {
            if viewModel.isLibraryVisible {
                LibraryView(viewModel: viewModel)
                    .frame(minWidth: 190, idealWidth: 224, maxWidth: 280)
                    .background(.ultraThinMaterial)
            }

            ReaderPaneView(viewModel: viewModel)
                .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.isInspectorVisible {
                SidebarView(viewModel: viewModel)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                    .background(.regularMaterial)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 980, minHeight: 680)
        .preferredColorScheme(preferredColorScheme)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    viewModel.isLibraryVisible.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(viewModel.isLibraryVisible ? "隐藏论文库" : "显示论文库")

                if let paper = viewModel.selectedPaper {
                    Text(paper.title)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: 420, alignment: .leading)
                } else {
                    Text("PaperMind")
                        .font(.headline)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                inspectorButton(
                    section: .chat,
                    symbol: "bubble.left.and.bubble.right",
                    help: "AI 讨论"
                )
                .keyboardShortcut("a", modifiers: [.command, .shift])

                inspectorButton(
                    section: .notes,
                    symbol: "note.text",
                    help: "论文笔记"
                )
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Menu {
                    Picker("外观", selection: Binding(
                        get: { viewModel.appTheme },
                        set: { viewModel.applyTheme($0) }
                    )) {
                        Label("浅色", systemImage: "sun.max").tag(AppTheme.light)
                        Label("深色", systemImage: "moon").tag(AppTheme.dark)
                    }

                    Divider()

                    Button("AI 设置…") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("更多")
            }
        }
    }

    private func inspectorButton(
        section: SidebarSection,
        symbol: String,
        help: String
    ) -> some View {
        Button {
            if viewModel.isInspectorVisible, viewModel.sidebarSection == section {
                viewModel.isInspectorVisible = false
            } else {
                viewModel.sidebarSection = section
                viewModel.isInspectorVisible = true
            }
        } label: {
            Image(systemName: symbol)
                .symbolVariant(
                    viewModel.isInspectorVisible && viewModel.sidebarSection == section
                    ? .fill
                    : .none
                )
        }
        .help(help)
    }

    private var preferredColorScheme: ColorScheme {
        viewModel.appTheme == .light ? .light : .dark
    }
}
