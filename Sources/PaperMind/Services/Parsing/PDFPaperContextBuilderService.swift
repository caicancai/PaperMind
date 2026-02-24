import Foundation
import PDFKit

struct PDFPaperContextBuilderService: PaperContextBuilderService {
    let perPageSampleLimit: Int
    let totalSampleLimit: Int

    init(perPageSampleLimit: Int = 900, totalSampleLimit: Int = 24_000) {
        self.perPageSampleLimit = perPageSampleLimit
        self.totalSampleLimit = totalSampleLimit
    }

    func buildKnowledge(for paper: Paper) async throws -> PaperKnowledge {
        guard let document = PDFDocument(url: paper.fileURL) else {
            throw PMError.notFound("无法打开论文文件：\(paper.fileURL.lastPathComponent)")
        }

        var sampledParts: [String] = []
        sampledParts.reserveCapacity(document.pageCount)

        var sampledCount = 0
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let text = page.string else {
                continue
            }

            let normalized = normalize(text)
            guard !normalized.isEmpty else { continue }

            let perPageSample = String(normalized.prefix(perPageSampleLimit))
            sampledParts.append("[Page \(pageIndex + 1)] \(perPageSample)")
            sampledCount += perPageSample.count

            if sampledCount >= totalSampleLimit {
                break
            }
        }

        let merged = sampledParts.joined(separator: "\n\n")
        let clipped = String(merged.prefix(totalSampleLimit))

        return PaperKnowledge(
            generatedAt: Date(),
            pageCount: document.pageCount,
            sampledCharacterCount: clipped.count,
            sampledText: clipped
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
