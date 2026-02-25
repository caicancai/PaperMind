import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isImporterPresented = false

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("PaperMind", systemImage: "doc.text.magnifyingglass")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Spacer()
                    Button("导入 PDF") {
                        isImporterPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.16, green: 0.42, blue: 0.94))
                }
                Text("已导入 \(viewModel.papers.count) 篇论文")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.white.opacity(0.64), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            List(viewModel.papers, selection: Binding(
                get: { viewModel.selectedPaperID },
                set: { newValue in
                    Task { await viewModel.didSelectPaper(id: newValue) }
                }
            )) { paper in
                paperRow(paper)
                    .tag(paper.id)
                    .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.white.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Button("刷新") {
                    Task { await viewModel.refreshPapers() }
                }
                .buttonStyle(.bordered)

                Button("关闭当前") {
                    viewModel.closeCurrentPaper()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedPaperID == nil)

                Spacer()

                Button("删除选中") {
                    Task { await viewModel.removeSelectedPaper() }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.selectedPaperID == nil)
            }
            .font(.callout)
        }
        .padding(6)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await viewModel.importPaper(from: url)
                }
            case .failure:
                break
            }
        }
    }

    @ViewBuilder
    private func paperRow(_ paper: Paper) -> some View {
        let selected = viewModel.selectedPaperID == paper.id
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: selected ? "doc.richtext.fill" : "doc.plaintext")
                .foregroundStyle(selected ? Color(red: 0.14, green: 0.38, blue: 0.88) : .secondary)
                .font(.callout)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(paper.title)
                    .font(.system(.body, design: .rounded, weight: selected ? .semibold : .regular))
                    .lineLimit(2)
                Text(paper.fileURL.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selected ? Color(red: 0.89, green: 0.94, blue: 1.00) : Color.white.opacity(0.5))
        )
    }
}
