import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isImporterPresented = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Papers")
                    .font(.headline)
                Spacer()
                Button("导入 PDF") {
                    isImporterPresented = true
                }
            }

            List(viewModel.papers, selection: Binding(
                get: { viewModel.selectedPaperID },
                set: { newValue in
                    Task { await viewModel.didSelectPaper(id: newValue) }
                }
            )) { paper in
                VStack(alignment: .leading, spacing: 4) {
                    Text(paper.title)
                        .font(.body)
                    Text(paper.fileURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(paper.id)
            }

            HStack {
                Button("刷新") {
                    Task { await viewModel.refreshPapers() }
                }

                Button("关闭当前") {
                    viewModel.closeCurrentPaper()
                }
                .disabled(viewModel.selectedPaperID == nil)

                Spacer()

                Button("删除选中") {
                    Task { await viewModel.removeSelectedPaper() }
                }
                .disabled(viewModel.selectedPaperID == nil)
            }
        }
        .padding(14)
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
}
