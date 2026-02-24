import SwiftUI

struct AISettingsFormView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSettingsProvider: AIProvider = .openai

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                List(selection: $selectedSettingsProvider) {
                    Section("Providers") {
                        settingsProviderRow(.auto)
                        settingsProviderRow(.openai)
                        settingsProviderRow(.deepseek)
                        settingsProviderRow(.kimi)
                    }
                }
                .frame(width: 150, height: 240)
                .onAppear {
                    if selectedSettingsProvider == .auto {
                        selectedSettingsProvider = .openai
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Picker("默认 Provider", selection: $viewModel.aiProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedSettingsProvider {
                    case .openai:
                        labeledTextField("OpenAI Model", text: $viewModel.openAIModel, placeholder: "gpt-4o-mini")
                        SecureField("OpenAI API Key", text: $viewModel.openAIAPIKeyDraft)
                            .textFieldStyle(.roundedBorder)
                    case .deepseek:
                        labeledTextField("DeepSeek Model", text: $viewModel.deepSeekModel, placeholder: "deepseek-chat")
                        SecureField("DeepSeek API Key", text: $viewModel.deepSeekAPIKeyDraft)
                            .textFieldStyle(.roundedBorder)
                    case .kimi:
                        labeledTextField("Kimi Model", text: $viewModel.kimiModel, placeholder: "moonshot-v1-8k")
                        SecureField("Kimi API Key", text: $viewModel.kimiAPIKeyDraft)
                            .textFieldStyle(.roundedBorder)
                    case .auto:
                        Text("Auto 模式会按 OpenAI -> DeepSeek -> Kimi 尝试已配置的 Key。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(width: 320, height: 240, alignment: .topLeading)
            }

            HStack {
                Button("保存并应用") {
                    viewModel.saveAIConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.11, green: 0.52, blue: 0.78))

                aiConfigStatus
                Spacer()
            }
            .font(.caption)
        }
    }

    private func labeledTextField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }

    private func settingsProviderRow(_ provider: AIProvider) -> some View {
        HStack(spacing: 8) {
            Image(systemName: provider == .auto ? "bolt.circle" : "network")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(provider.displayName)
                .font(.callout)
            Spacer()
        }
        .tag(provider)
    }

    @ViewBuilder
    private var aiConfigStatus: some View {
        switch viewModel.aiConfigState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("应用中...")
            }
        case .success:
            Text("已应用")
                .foregroundStyle(.green)
        case .failure(let message):
            Text(message)
                .lineLimit(1)
                .foregroundStyle(.red)
        }
    }
}
