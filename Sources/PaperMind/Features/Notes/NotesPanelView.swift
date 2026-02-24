import SwiftUI

struct NotesPanelView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            createThreadSection
            Divider()
            threadListSection
            Divider()
            activeThreadSection
        }
    }

    private var header: some View {
        HStack {
            Text("评论")
                .font(.headline)

            Spacer()

            Toggle("显示已解决", isOn: $viewModel.showResolvedThreads)
                .toggleStyle(.switch)
                .labelsHidden()
            Text("已解决")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var createThreadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("新建评论线程")
                .font(.subheadline)

            TextField("标题（可选）", text: $viewModel.newThreadTitleDraft)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $viewModel.newThreadCommentDraft)
                .frame(height: 70)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray.opacity(0.3)))

            HStack {
                Button("从选区填充") {
                    viewModel.fillDraftFromSelection()
                }
                .disabled(viewModel.currentSelection == nil)

                Button("创建评论") {
                    Task { await viewModel.createCommentThreadFromDraft() }
                }

                Spacer()
            }

            statusView
        }
    }

    private var threadListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("线程")
                .font(.subheadline)

            List(selection: Binding(
                get: { viewModel.activeThreadID },
                set: { viewModel.focusThread($0) }
            )) {
                ForEach(viewModel.visibleThreads) { thread in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(thread.status == .open ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(thread.title)
                                .lineLimit(1)
                            Text("P\((thread.pageIndex ?? 0) + 1) · \(thread.comments.count) 条")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .tag(thread.id)
                }
            }
            .frame(minHeight: 130)
        }
    }

    private var activeThreadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("线程详情")
                .font(.subheadline)

            if let thread = viewModel.activeThread {
                HStack {
                    Text(thread.status == .open ? "未解决" : "已解决")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((thread.status == .open ? Color.orange : Color.green).opacity(0.15))
                        .clipShape(Capsule())

                    Spacer()

                    Button(thread.status == .open ? "标记已解决" : "恢复为未解决") {
                        Task { await viewModel.setThreadResolved(thread.status == .open, threadID: thread.id) }
                    }

                    Button("删除") {
                        Task { await viewModel.deleteNote(id: thread.id) }
                    }
                }

                if let quote = thread.quote, !quote.isEmpty {
                    Text("引用：\(quote)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(thread.comments) { comment in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(comment.role == .author ? "作者" : "回复")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(comment.content)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(comment.role == .author ? .blue.opacity(0.08) : .gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 200)

                HStack {
                    TextField("回复此线程...", text: $viewModel.replyDraft)
                        .textFieldStyle(.roundedBorder)

                    Button("发送") {
                        Task { await viewModel.addReplyToActiveThread() }
                    }
                }
            } else {
                Text("请选择一个线程")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.noteState {
        case .idle:
            EmptyView()
        case .loading:
            HStack { ProgressView(); Text("保存中...") }
        case .success:
            Text("已保存")
                .foregroundStyle(.green)
        case .failure(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }
}
