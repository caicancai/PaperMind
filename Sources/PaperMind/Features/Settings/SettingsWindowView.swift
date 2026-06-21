import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("配置模型与密钥，聊天面板可按次选择回答模型。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()
            AISettingsFormView(viewModel: viewModel)
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(PaperTheme.canvas(for: colorScheme))
        .tint(PaperTheme.accent)
        .frame(minWidth: 700, minHeight: 460)
    }
}
