import Foundation

final class JSONPaperRepository: PaperRepository {
    private let store: JSONFileStore
    private let fileURL: URL

    init(store: JSONFileStore, fileURL: URL) {
        self.store = store
        self.fileURL = fileURL
    }

    func listPapers() async throws -> [Paper] {
        let papers = try store.load([Paper].self, from: fileURL, defaultValue: [])
        return papers.sorted { $0.createdAt > $1.createdAt }
    }

    func addPaper(fileURL: URL) async throws -> Paper {
        var papers = try store.load([Paper].self, from: self.fileURL, defaultValue: [])

        if let existing = papers.first(where: { $0.fileURL == fileURL }) {
            return existing
        }

        let now = Date()
        let paper = Paper(
            id: UUID(),
            title: fileURL.deletingPathExtension().lastPathComponent,
            authors: [],
            fileURL: fileURL,
            tags: [],
            createdAt: now,
            lastOpenedAt: now
        )

        papers.append(paper)
        try store.save(papers, to: self.fileURL)
        return paper
    }

    func removePaper(id: UUID) async throws {
        var papers = try store.load([Paper].self, from: fileURL, defaultValue: [])
        papers.removeAll { $0.id == id }
        try store.save(papers, to: fileURL)
    }
}
