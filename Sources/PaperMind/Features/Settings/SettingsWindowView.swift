import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Settings")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                    Text("配置模型与密钥，聊天面板可按次选择回答模型。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                AISettingsFormView(viewModel: viewModel)
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(minWidth: 700, minHeight: 460)
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.10, green: 0.11, blue: 0.13),
                Color(red: 0.08, green: 0.09, blue: 0.10)
            ]
        }
        return [
            Color(red: 0.96, green: 0.98, blue: 1.00),
            Color(red: 0.94, green: 0.96, blue: 0.99)
        ]
    }
}
