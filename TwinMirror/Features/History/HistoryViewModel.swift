import Foundation
import SwiftUI

@MainActor
@Observable
final class HistoryViewModel {
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        let items: [HistoryItem]
    }

    private(set) var items: [HistoryItem] = []
    private(set) var totalCount: Int = 0
    private(set) var freeLimitReached: Bool = false
    private(set) var isLoading: Bool = false
    var errorMessage: String?

    let service: HistoryServicing
    private let isPremiumProvider: @Sendable () -> Bool

    init(service: HistoryServicing, isPremiumProvider: @escaping @Sendable () -> Bool) {
        self.service = service
        self.isPremiumProvider = isPremiumProvider
    }

    var isEmpty: Bool { items.isEmpty }
    var sections: [Section] { Self.groupIntoSections(items, now: Date(), calendar: .current) }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await service.list(isPremium: isPremiumProvider())
            items = response.items
            totalCount = response.totalCount
            freeLimitReached = response.freeLimitReached
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func delete(_ item: HistoryItem) async {
        let snapshot = items
        items.removeAll { $0.id == item.id }
        do {
            try await service.delete(id: item.id, isPremium: isPremiumProvider())
            totalCount = max(0, totalCount - 1)
        } catch {
            items = snapshot
            errorMessage = error.localizedDescription
        }
    }

    /// Pure helper — kept static so tests can exercise it without a service.
    static func groupIntoSections(
        _ items: [HistoryItem],
        now: Date,
        calendar: Calendar
    ) -> [Section] {
        let todayStart = calendar.startOfDay(for: now)
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return items.isEmpty ? [] : [Section(id: "all", title: "履歴", items: items)]
        }

        var today: [HistoryItem] = []
        var yesterday: [HistoryItem] = []
        var thisMonth: [HistoryItem] = []
        var older: [HistoryItem] = []

        for item in items {
            let d = item.createdAt
            if d >= todayStart {
                today.append(item)
            } else if d >= yesterdayStart {
                yesterday.append(item)
            } else if d >= monthStart {
                thisMonth.append(item)
            } else {
                older.append(item)
            }
        }

        var sections: [Section] = []
        if !today.isEmpty { sections.append(Section(id: "today", title: "今日", items: today)) }
        if !yesterday.isEmpty { sections.append(Section(id: "yesterday", title: "昨日", items: yesterday)) }
        if !thisMonth.isEmpty { sections.append(Section(id: "month", title: "今月", items: thisMonth)) }
        if !older.isEmpty { sections.append(Section(id: "older", title: "それ以前", items: older)) }
        return sections
    }
}
