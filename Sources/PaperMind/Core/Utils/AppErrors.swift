import Foundation

enum PMError: Error, LocalizedError {
    case invalidInput(String)
    case notFound(String)
    case storage(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message), .notFound(let message), .storage(let message), .network(let message):
            return message
        }
    }
}

enum RequestState: Equatable {
    case idle
    case loading
    case success
    case failure(String)
}
