import Foundation

final class JSONNoteRepository: NoteRepository {
    private let store: JSONFileStore
    private let fileURL: URL

    init(store: JSONFileStore, fileURL: URL) {
        self.store = store
        self.fileURL = fileURL
    }

    func listNotes(paperID: UUID) async throws -> [Note] {
        let all = try store.load([Note].self, from: fileURL, defaultValue: [])
        return all.filter { $0.paperID == paperID }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func save(note: Note) async throws {
        var all = try store.load([Note].self, from: fileURL, defaultValue: [])

        if let index = all.firstIndex(where: { $0.id == note.id }) {
            all[index] = note
        } else {
            all.append(note)
        }

        try store.save(all, to: fileURL)
    }

    func delete(noteID: UUID) async throws {
        var all = try store.load([Note].self, from: fileURL, defaultValue: [])
        all.removeAll { $0.id == noteID }
        try store.save(all, to: fileURL)
    }
}
