import SwiftUI

struct AISettingsFormView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSettingsProvider: AIProvider = .openai
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HSplitView {
            providerList
                .frame(minWidth: 190, idealWidth: 210, maxWidth: 230)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("默认 Provider")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("默认 Provider", selection: $viewModel.aiProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        switch selectedSettingsProvider {
                        case .openai:
                            providerHeader("OpenAI", icon: "sparkles", configured: hasKey(.openai))
                            labeledTextField("Model", text: $viewModel.openAIModel, placeholder: "gpt-4o-mini")
                            labeledSecureField("API Key", text: $viewModel.openAIAPIKeyDraft, placeholder: "sk-...")
                        case .deepseek:
                            providerHeader("DeepSeek", icon: "scope", configured: hasKey(.deepseek))
                            labeledTextField("Model", text: $viewModel.deepSeekModel, placeholder: "deepseek-chat")
                            labeledSecureField("API Key", text: $viewModel.deepSeekAPIKeyDraft, placeholder: "sk-...")
                        case .kimi:
                            providerHeader("Kimi", icon: "moon.stars", configured: hasKey(.kimi))
                            labeledTextField("Model", text: $viewModel.kimiModel, placeholder: "kimi-2.5")
                            labeledSecureField("API Key", text: $viewModel.kimiAPIKeyDraft, placeholder: "sk-...")
                        case .auto:
                            providerHeader("Auto Routing", icon: "bolt.circle", configured: true)
                            Text("按 OpenAI -> DeepSeek -> Kimi 顺序尝试已配置 Key 的 Provider。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .groupBoxStyle(.automatic)

                Spacer()

                HStack(spacing: 10) {
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
            .padding(14)
            .background(detailFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(minHeight: 330)
        .onAppear {
            if selectedSettingsProvider == .auto {
                selectedSettingsProvider = .openai
            }
        }
    }

    private var providerList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Providers")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            List(selection: $selectedSettingsProvider) {
                Section {
                    settingsProviderRow(.openai)
                    settingsProviderRow(.deepseek)
                    settingsProviderRow(.kimi)
                    settingsProviderRow(.auto)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(sidebarFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func labeledSecureField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            SecureField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
        }
    }

    private func settingsProviderRow(_ provider: AIProvider) -> some View {
        HStack(spacing: 8) {
            Image(systemName: providerIcon(provider))
                .font(.callout)
                .foregroundStyle(provider == .auto ? .orange : .secondary)
            Text(provider.displayName)
                .font(.callout)
            if provider != .auto {
                Text(hasKey(provider) ? "Configured" : "No Key")
                    .font(.caption2)
                    .foregroundStyle(hasKey(provider) ? .green : .secondary)
            }
            Spacer()
        }
        .tag(provider)
    }

    @ViewBuilder
    private func providerHeader(_ title: String, icon: String, configured: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
                .font(.headline)
            Spacer()
            if configured {
                Label("Ready", systemImage: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Label("Missing Key", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
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

    private func providerIcon(_ provider: AIProvider) -> String {
        switch provider {
        case .auto: return "bolt.circle"
        case .openai: return "sparkles"
        case .deepseek: return "scope"
        case .kimi: return "moon.stars"
        }
    }

    private func hasKey(_ provider: AIProvider) -> Bool {
        switch provider {
        case .openai:
            return !viewModel.openAIAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .deepseek:
            return !viewModel.deepSeekAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .kimi:
            return !viewModel.kimiAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .auto:
            return true
        }
    }

    private var sidebarFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.72)
    }

    private var detailFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.24) : Color.white.opacity(0.74)
    }
}
