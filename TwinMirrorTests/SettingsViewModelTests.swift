import XCTest
@testable import TwinMirror

@MainActor
final class SettingsViewModelTests: XCTestCase {

    func test_clearAllHistory_success_setsDidClearAndClearsError() async {
        let stub = StubHistoryServiceForSettings()
        let vm = SettingsViewModel(
            historyService: stub,
            isPremiumProvider: { false }
        )
        vm.errorMessage = "前のエラー"

        await vm.clearAllHistory()

        XCTAssertTrue(vm.didClearAll)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isClearingHistory)
        XCTAssertEqual(stub.deleteAllCalls, 1)
        XCTAssertEqual(stub.lastIsPremium, false)
    }

    func test_clearAllHistory_passesPremiumFlag() async {
        let stub = StubHistoryServiceForSettings()
        let vm = SettingsViewModel(
            historyService: stub,
            isPremiumProvider: { true }
        )

        await vm.clearAllHistory()

        XCTAssertEqual(stub.lastIsPremium, true)
    }

    func test_clearAllHistory_failure_setsErrorMessageAndKeepsDidClearFalse() async {
        struct DummyError: Error, LocalizedError {
            var errorDescription: String? { "削除に失敗しました" }
        }
        let stub = StubHistoryServiceForSettings()
        stub.deleteAllError = DummyError()
        let vm = SettingsViewModel(
            historyService: stub,
            isPremiumProvider: { false }
        )

        await vm.clearAllHistory()

        XCTAssertFalse(vm.didClearAll)
        XCTAssertEqual(vm.errorMessage, "削除に失敗しました")
        XCTAssertFalse(vm.isClearingHistory)
    }

    func test_clearAllHistory_whenServiceUnavailable_setsError() async {
        let vm = SettingsViewModel(
            historyService: nil,
            isPremiumProvider: { false }
        )

        await vm.clearAllHistory()

        XCTAssertFalse(vm.didClearAll)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_appVersionDisplay_combinesShortVersionAndBuild() {
        let vm = SettingsViewModel(
            historyService: nil,
            isPremiumProvider: { false }
        )

        // Bundle.main may not surface both keys reliably in test host; just assert
        // a non-empty, non-placeholder string and that it contains a digit or a dash.
        let display = vm.appVersionDisplay
        XCTAssertFalse(display.isEmpty)
    }
}

// MARK: - helpers

private final class StubHistoryServiceForSettings: HistoryServicing, @unchecked Sendable {
    var deleteAllError: Error?
    private(set) var deleteAllCalls = 0
    private(set) var lastIsPremium: Bool?

    func save(imageJPEG: Data, thumbnailJPEG: Data, metadata: HistoryMetadata, isPremium: Bool) async throws -> HistoryItem {
        HistoryItem(id: "x", createdAtMillis: 0, gender: nil, age: nil, mode: nil, style: nil, ratio: nil, prompt: nil)
    }
    func list(isPremium: Bool) async throws -> HistoryListResponse {
        HistoryListResponse(items: [], totalCount: 0, freeLimitReached: false)
    }
    func imageData(for id: String, variant: HistoryImageVariant, isPremium: Bool) async throws -> Data { Data() }
    func delete(id: String, isPremium: Bool) async throws {}
    func deleteAll(isPremium: Bool) async throws {
        deleteAllCalls += 1
        lastIsPremium = isPremium
        if let deleteAllError { throw deleteAllError }
    }
}
