import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showAISettingsPopover = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("AI 讨论", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 6) {
                        Button {
                            viewModel.applyTheme(.light)
                        } label: {
                            Image(systemName: "sun.max.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.appTheme == .light ? .orange : .gray)
                        .opacity(viewModel.appTheme == .light ? 1.0 : 0.72)
                        .help("切换到浅色模式")

                        Button {
                            viewModel.applyTheme(.dark)
                        } label: {
                            Image(systemName: "moon.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.appTheme == .dark ? .indigo : .gray)
                        .opacity(viewModel.appTheme == .dark ? 1.0 : 0.72)
                        .help("切换到深色模式")
                    }
                    Button {
                        showAISettingsPopover = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .buttonStyle(.bordered)
                    .help("打开 AI 设置")
                }

                thinkingModeSection
            }
            .padding(12)
            .background(sectionFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            paperReadStatus

            ChatPanelView(viewModel: viewModel)
        }
        .padding(8)
        .popover(isPresented: $showAISettingsPopover, arrowEdge: .top) {
            aiSettingsPopover
        }
    }

    private var aiSettingsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI 设置")
                    .font(.headline)
                Spacer()
            }

            AISettingsFormView(viewModel: viewModel)
        }
        .padding(16)
        .frame(width: 520)
    }

    @ViewBuilder
    private var paperReadStatus: some View {
        switch viewModel.paperContextState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("AI 正在阅读当前论文...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(capsuleFill, in: Capsule())
        case .success:
            Text("论文上下文已加载")
                .font(.caption2)
                .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 0.30))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(capsuleFill, in: Capsule())
        case .failure(let message):
            Text(message)
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(capsuleFill, in: Capsule())
        }
    }

    private var sectionFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.26) : Color.white.opacity(0.64)
    }

    private var capsuleFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.34) : Color.white.opacity(0.55)
    }

    private var thinkingModeSelector: some View {
        HStack(spacing: 4) {
            ForEach(ThinkingMode.allCases) { mode in
                Button {
                    viewModel.thinkingMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .foregroundStyle(viewModel.thinkingMode == mode ? Color.white : Color.secondary)
                        .background(
                            Capsule()
                                .fill(
                                    viewModel.thinkingMode == mode
                                    ? Color(red: 0.12, green: 0.48, blue: 0.92)
                                    : Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.rawValue)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("思考模式")
    }

    @ViewBuilder
    private var thinkingModeSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                thinkingModeLabel
                Spacer(minLength: 8)
                thinkingModeSelector
                    .frame(width: 190)
                    .layoutPriority(1)
            }

            VStack(alignment: .leading, spacing: 6) {
                thinkingModeLabel
                thinkingModeSelector
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var thinkingModeLabel: some View {
        Text("思考模式")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
