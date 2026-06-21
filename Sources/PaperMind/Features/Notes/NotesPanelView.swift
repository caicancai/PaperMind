import SwiftUI

struct NotesPanelView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var kindFilter: NoteKind?
    @State private var titleDraft = ""
    @State private var contentDraft = ""
    @State private var kindDraft: NoteKind = .insight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            filters
            noteList
            Divider()
            noteEditor
        }
        .onAppear {
            syncEditor()
        }
        .onChange(of: viewModel.activeThreadID) { _ in
            syncEditor()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("\(viewModel.notes.count) 条笔记")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await viewModel.createNoteFromCurrentSelection() }
            } label: {
                Image(systemName: "highlighter")
            }
            .disabled(viewModel.currentSelection == nil)
            .help("保存当前选区")

            Button {
                Task { await viewModel.createFreeNote() }
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("新建笔记")
        }
        .buttonStyle(.borderless)
    }

    private var filters: some View {
        HStack(spacing: 8) {
            TextField("搜索标题、正文或原文", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Picker("类型", selection: $kindFilter) {
                Text("全部").tag(NoteKind?.none)
                ForEach(NoteKind.allCases) { kind in
                    Text(kind.title).tag(NoteKind?.some(kind))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 82)
        }
    }

    private var noteList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 7) {
                if filteredNotes.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: "note.text")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(viewModel.notes.isEmpty ? "还没有笔记" : "没有匹配的笔记")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if viewModel.notes.isEmpty {
                            Text("在 PDF 中选中文字，然后点击“保存笔记”。")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(filteredNotes) { note in
                        noteCard(note)
                    }
                }
            }
            .padding(3)
        }
        .frame(minHeight: 130, maxHeight: 260)
    }

    private func noteCard(_ note: Note) -> some View {
        let isActive = note.id == viewModel.activeThreadID
        return Button {
            viewModel.focusThread(note.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Label(note.kind.title, systemImage: note.kind.systemImage)
                        .font(.caption2)
                        .foregroundStyle(kindColor(note.kind))
                    Spacer()
                    if let pageIndex = note.pageIndex {
                        Text("P\(pageIndex + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let preview = notePreview(note) {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isActive ? PaperTheme.selection(for: colorScheme) : PaperTheme.sheet(for: colorScheme).opacity(0.7),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isActive ? PaperTheme.accent.opacity(0.6) : PaperTheme.rule(for: colorScheme).opacity(0.35),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var noteEditor: some View {
        if let note = viewModel.activeThread {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("编辑笔记")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    statusView
                }

                HStack(spacing: 8) {
                    Picker("类型", selection: $kindDraft) {
                        ForEach(NoteKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 104)

                    TextField("笔记标题", text: $titleDraft)
                        .textFieldStyle(.roundedBorder)
                }

                if let quote = note.quote, !quote.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("原文")
                                .font(.caption2)
                                .fontWeight(.semibold)
                            Spacer()
                            if note.anchorRect != nil {
                                Label("已锚定", systemImage: "link")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(quote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .background(panelFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                TextEditor(text: $contentDraft)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .frame(minHeight: 90)
                    .background(inputFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                HStack {
                    Button("删除", role: .destructive) {
                        Task { await viewModel.deleteNote(id: note.id) }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        Task {
                            await viewModel.updateNote(
                                id: note.id,
                                title: titleDraft,
                                content: contentDraft,
                                kind: kindDraft
                            )
                        }
                    } label: {
                        Label("保存", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.small)
            }
        } else {
            Text("选择一条笔记进行编辑")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch viewModel.noteState {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView()
                .controlSize(.small)
        case .success:
            Label("已保存", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
        case .failure(let message):
            Text(message)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    private var filteredNotes: [Note] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return viewModel.notes.filter { note in
            let matchesKind = kindFilter == nil || note.kind == kindFilter
            guard matchesKind else { return false }
            guard !query.isEmpty else { return true }
            return note.title.lowercased().contains(query)
                || note.content.lowercased().contains(query)
                || (note.quote?.lowercased().contains(query) ?? false)
        }
    }

    private func syncEditor() {
        guard let note = viewModel.activeThread else {
            titleDraft = ""
            contentDraft = ""
            kindDraft = .insight
            return
        }
        titleDraft = note.title
        contentDraft = note.content
        kindDraft = note.kind
    }

    private func notePreview(_ note: Note) -> String? {
        let content = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if !content.isEmpty { return content }
        return note.quote?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func kindColor(_ kind: NoteKind) -> Color {
        switch kind {
        case .insight: return .blue
        case .question: return .orange
        case .conclusion: return .green
        case .method: return .purple
        case .experiment: return .indigo
        case .toRead: return .pink
        }
    }

    private var panelFill: Color {
        PaperTheme.sheet(for: colorScheme)
    }

    private var inputFill: Color {
        PaperTheme.raisedSheet(for: colorScheme)
    }
}
