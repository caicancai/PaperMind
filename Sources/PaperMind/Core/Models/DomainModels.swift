import Foundation

struct Paper: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var title: String
    var authors: [String]
    var fileURL: URL
    var tags: [String]
    var createdAt: Date
    var lastOpenedAt: Date?
}

struct TextSelection: Codable, Equatable, Hashable {
    var paperID: UUID
    var pageIndex: Int
    var selectedText: String
    var contextBefore: String?
    var contextAfter: String?
}

struct TranslationRecord: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var selection: TextSelection
    var sourceLang: String
    var targetLang: String
    var translatedText: String
    var createdAt: Date
}

enum ChatRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var sessionID: UUID
    var role: ChatRole
    var content: String
    var createdAt: Date
}

struct Note: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var paperID: UUID
    var title: String
    var content: String
    var quote: String?
    var pageIndex: Int?
    var anchorRect: NoteAnchorRect?
    var tags: [String]
    var status: NoteStatus
    var comments: [NoteComment]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        paperID: UUID,
        title: String,
        content: String,
        quote: String?,
        pageIndex: Int?,
        anchorRect: NoteAnchorRect? = nil,
        tags: [String],
        status: NoteStatus = .open,
        comments: [NoteComment] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.paperID = paperID
        self.title = title
        self.content = content
        self.quote = quote
        self.pageIndex = pageIndex
        self.anchorRect = anchorRect
        self.tags = tags
        self.status = status
        self.comments = comments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case paperID
        case title
        case content
        case quote
        case pageIndex
        case anchorRect
        case tags
        case status
        case comments
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        paperID = try container.decode(UUID.self, forKey: .paperID)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        quote = try container.decodeIfPresent(String.self, forKey: .quote)
        pageIndex = try container.decodeIfPresent(Int.self, forKey: .pageIndex)
        anchorRect = try container.decodeIfPresent(NoteAnchorRect.self, forKey: .anchorRect)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        status = try container.decodeIfPresent(NoteStatus.self, forKey: .status) ?? .open
        comments = try container.decodeIfPresent([NoteComment].self, forKey: .comments) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Migrate legacy single-content notes into one comment message.
        if comments.isEmpty, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            comments = [
                NoteComment(
                    id: UUID(),
                    role: .author,
                    content: content,
                    createdAt: createdAt
                )
            ]
        }
    }
}

enum NoteStatus: String, Codable, Equatable, Hashable {
    case open
    case resolved
}

enum NoteCommentRole: String, Codable, Equatable, Hashable {
    case author
    case reply
}

struct NoteComment: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var role: NoteCommentRole
    var content: String
    var createdAt: Date
}

struct NoteAnchorRect: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.size.width
        height = rect.size.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct PaperContext: Codable, Equatable {
    var paper: Paper
    var selection: TextSelection?
}

enum ChatMode: String, CaseIterable, Identifiable {
    case explain = "Explain"
    case summarize = "Summarize"

    var id: String { rawValue }
}
