import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("Inspector", selection: $viewModel.sidebarSection) {
                    Label("AI", systemImage: "bubble.left.and.bubble.right")
                        .tag(SidebarSection.chat)
                    Label("笔记", systemImage: "note.text")
                        .tag(SidebarSection.notes)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button {
                    viewModel.isInspectorVisible = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭 Inspector")
            }
            .padding(.horizontal, 12)
            .frame(height: 44)

            Divider()

            Group {
                if viewModel.sidebarSection == .chat {
                    ChatPanelView(viewModel: viewModel)
                } else {
                    NotesPanelView(viewModel: viewModel)
                }
            }
            .padding(12)
        }
        .background(PaperTheme.raisedSheet(for: colorScheme))
    }
}
