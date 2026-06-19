import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isImporterPresented = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader
            Divider()
            paperList
            Divider()
            libraryFooter
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await viewModel.importPaper(from: url) }
        }
    }

    private var libraryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("论文库")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.papers.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("搜索论文", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var paperList: some View {
        List(filteredPapers, selection: Binding(
            get: { viewModel.selectedPaperID },
            set: { newValue in
                Task { await viewModel.didSelectPaper(id: newValue) }
            }
        )) { paper in
            HStack(spacing: 9) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(paper.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                    Text(paper.fileURL.lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
            .tag(paper.id)
            .contextMenu {
                Button("关闭") {
                    if viewModel.selectedPaperID == paper.id {
                        viewModel.closeCurrentPaper()
                    }
                }
                Button("删除", role: .destructive) {
                    Task {
                        if viewModel.selectedPaperID != paper.id {
                            await viewModel.didSelectPaper(id: paper.id)
                        }
                        await viewModel.removeSelectedPaper()
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .overlay {
            if filteredPapers.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: searchText.isEmpty ? "doc.badge.plus" : "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "导入第一篇论文" : "没有匹配的论文")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var libraryFooter: some View {
        HStack(spacing: 6) {
            Button {
                isImporterPresented = true
            } label: {
                Image(systemName: "plus")
            }
            .help("导入 PDF")

            Button {
                Task { await viewModel.refreshPapers() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新")

            Spacer()

            Button {
                viewModel.closeCurrentPaper()
            } label: {
                Image(systemName: "xmark")
            }
            .disabled(viewModel.selectedPaperID == nil)
            .help("关闭当前论文")

            Button(role: .destructive) {
                Task { await viewModel.removeSelectedPaper() }
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.selectedPaperID == nil)
            .help("删除选中论文")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    private var filteredPapers: [Paper] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.papers }
        return viewModel.papers.filter {
            $0.title.lowercased().contains(query)
                || $0.fileURL.lastPathComponent.lowercased().contains(query)
        }
    }
}
