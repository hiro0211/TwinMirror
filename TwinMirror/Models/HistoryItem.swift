import Foundation

struct HistoryItem: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let createdAtMillis: Int64
    let gender: String?
    let age: String?
    let mode: String?
    let style: String?
    let ratio: String?
    let prompt: String?

    var createdAt: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAtMillis) / 1000)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtMillis = "createdAt"
        case gender, age, mode, style, ratio, prompt
    }
}

struct HistoryMetadata: Sendable, Equatable {
    var gender: String?
    var age: String?
    var mode: String?
    var style: String?
    var ratio: String?
    var prompt: String?
}

struct HistoryListResponse: Sendable, Codable {
    let items: [HistoryItem]
    let totalCount: Int
    let freeLimitReached: Bool
}
