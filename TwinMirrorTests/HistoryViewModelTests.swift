import XCTest
@testable import TwinMirror

@MainActor
final class HistoryViewModelTests: XCTestCase {

    private func makeItems(_ count: Int) -> [HistoryItem] {
        (0..<count).map { i in
            HistoryItem(
                id: "id-\(i)",
                createdAtMillis: Int64(1716000000000 + i * 1000),
                gender: "female", age: "5", mode: "fast",
                style: "photorealistic", ratio: "50_50", prompt: "p"
            )
        }
    }

    func test_load_populatesItemsAndFlags() async {
        let stub = StubHistoryService(
            listResult: HistoryListResponse(items: makeItems(3), totalCount: 5, freeLimitReached: true)
        )
        let vm = HistoryViewModel(service: stub, isPremiumProvider: { false })
        await vm.load()

        XCTAssertEqual(vm.items.count, 3)
        XCTAssertEqual(vm.totalCount, 5)
        XCTAssertTrue(vm.freeLimitReached)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
    }

    func test_load_premiumIsPassedThrough() async {
        let stub = StubHistoryService(
            listResult: HistoryListResponse(items: makeItems(7), totalCount: 7, freeLimitReached: false)
        )
        let vm = HistoryViewModel(service: stub, isPremiumProvider: { true })
        await vm.load()

        XCTAssertEqual(stub.lastIsPremium, true)
        XCTAssertEqual(vm.items.count, 7)
        XCTAssertFalse(vm.freeLimitReached)
    }

    func test_load_emptyState() async {
        let stub = StubHistoryService(
            listResult: HistoryListResponse(items: [], totalCount: 0, freeLimitReached: false)
        )
        let vm = HistoryViewModel(service: stub, isPremiumProvider: { false })
        await vm.load()

        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertTrue(vm.isEmpty)
        XCTAssertFalse(vm.freeLimitReached)
    }

    func test_load_setsErrorOnFailure() async {
        let stub = StubHistoryService(listError: HistoryServiceError.requestFailed(statusCode: 500, body: ""))
        let vm = HistoryViewModel(service: stub, isPremiumProvider: { false })
        await vm.load()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }

    func test_delete_optimisticallyRemovesItem() async {
        let initial = makeItems(3)
        let stub = StubHistoryService(
            listResult: HistoryListResponse(items: initial, totalCount: 3, freeLimitReached: false)
        )
        let vm = HistoryViewModel(service: stub, isPremiumProvider: { true })
        await vm.load()
        XCTAssertEqual(vm.items.count, 3)

        await vm.delete(initial[1])
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertFalse(vm.items.contains { $0.id == initial[1].id })
        XCTAssertEqual(stub.lastDeletedID, initial[1].id)
    }

    func test_delete_rollsBackOnFailure() async {
        let initial = makeItems(2)
        let stub = StubHistoryService(
            listResult: HistoryListResponse(items: initial, totalCount: 2, freeLimitReached: false),
            deleteError: HistoryServiceError.requestFailed(statusCode: 500, body: "")
        )
        let vm = HistoryViewModel(service: stub, isPremiumProvider: { true })
        await vm.load()
        await vm.delete(initial[0])

        XCTAssertEqual(vm.items.count, 2)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_groupedSections_buildsDateBuckets() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: now).addingTimeInterval(3600)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let thisMonth = cal.date(byAdding: .day, value: -10, to: today)!
        let older = cal.date(byAdding: .day, value: -60, to: today)!

        func item(_ id: String, _ d: Date) -> HistoryItem {
            HistoryItem(
                id: id, createdAtMillis: Int64(d.timeIntervalSince1970 * 1000),
                gender: nil, age: nil, mode: nil, style: nil, ratio: nil, prompt: nil
            )
        }
        let items = [
            item("t1", today),
            item("y1", yesterday),
            item("m1", thisMonth),
            item("o1", older),
        ]
        let sections = HistoryViewModel.groupIntoSections(items, now: now, calendar: cal)
        let titles = sections.map { $0.title }
        XCTAssertEqual(titles, ["今日", "昨日", "今月", "それ以前"])
        XCTAssertEqual(sections[0].items.map(\.id), ["t1"])
        XCTAssertEqual(sections[1].items.map(\.id), ["y1"])
        XCTAssertEqual(sections[2].items.map(\.id), ["m1"])
        XCTAssertEqual(sections[3].items.map(\.id), ["o1"])
    }
}

// MARK: - stub

private final class StubHistoryService: HistoryServicing, @unchecked Sendable {
    var listResult: HistoryListResponse?
    var listError: Error?
    var deleteError: Error?
    private(set) var lastIsPremium: Bool?
    private(set) var lastDeletedID: String?

    init(listResult: HistoryListResponse? = nil, listError: Error? = nil, deleteError: Error? = nil) {
        self.listResult = listResult
        self.listError = listError
        self.deleteError = deleteError
    }

    func save(imageJPEG: Data, thumbnailJPEG: Data, metadata: HistoryMetadata, isPremium: Bool) async throws -> HistoryItem {
        HistoryItem(id: "stub", createdAtMillis: 0, gender: nil, age: nil, mode: nil, style: nil, ratio: nil, prompt: nil)
    }
    func list(isPremium: Bool) async throws -> HistoryListResponse {
        lastIsPremium = isPremium
        if let listError { throw listError }
        return listResult ?? HistoryListResponse(items: [], totalCount: 0, freeLimitReached: false)
    }
    func imageData(for id: String, variant: HistoryImageVariant, isPremium: Bool) async throws -> Data {
        Data()
    }
    func delete(id: String, isPremium: Bool) async throws {
        lastDeletedID = id
        if let deleteError { throw deleteError }
    }
    func deleteAll(isPremium: Bool) async throws {}
}
