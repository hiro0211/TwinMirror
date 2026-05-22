import XCTest
@testable import TwinMirror

@MainActor
final class ReviewRequestServiceTests: XCTestCase {

    private let suiteName = "twinmirror.review.tests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func service(
        now: Date,
        version: String = "0.1.0"
    ) -> ReviewRequestService {
        ReviewRequestService(
            defaults: defaults,
            now: { now },
            bundleShortVersion: version
        )
    }

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    // MARK: - Bootstrap

    func test_bootstrap_setsInstallDateOnFirstRun() {
        let now = date("2026-05-22 10:00")
        let s = service(now: now)
        s.bootstrap()
        XCTAssertEqual(defaults.double(forKey: "twinmirror.review.installDate"), now.timeIntervalSince1970)
    }

    func test_bootstrap_doesNotOverwriteExistingInstallDate() {
        let firstRun = date("2026-05-01 10:00")
        let secondRun = date("2026-05-22 10:00")

        service(now: firstRun).bootstrap()
        service(now: secondRun).bootstrap()

        XCTAssertEqual(
            defaults.double(forKey: "twinmirror.review.installDate"),
            firstRun.timeIntervalSince1970
        )
    }

    // MARK: - Eligibility gates

    func test_shouldPresent_isFalse_whenInstalledLessThanThreeDays() {
        let installDate = date("2026-05-20 10:00")
        service(now: installDate).bootstrap()

        // 2 days later: not yet eligible.
        let s = service(now: date("2026-05-22 10:00"))
        s.recordPositiveEvent()
        s.recordPositiveEvent()
        XCTAssertFalse(s.shouldPresent)
    }

    func test_shouldPresent_isFalse_whenSuccessCountBelowThreshold() {
        let installDate = date("2026-05-01 10:00")
        service(now: installDate).bootstrap()

        let s = service(now: date("2026-05-22 10:00"))
        s.recordPositiveEvent() // 1 回だけ
        XCTAssertFalse(s.shouldPresent)
    }

    func test_shouldPresent_becomesTrue_whenAllGatesPass() {
        let installDate = date("2026-05-01 10:00")
        service(now: installDate).bootstrap()

        let s = service(now: date("2026-05-22 10:00"))
        s.recordPositiveEvent()
        s.recordPositiveEvent()
        XCTAssertTrue(s.shouldPresent)
    }

    // MARK: - Cooldown / version / lifetime cap

    func test_shouldPresent_isFalse_duringCooldownAfterMarkPresented() {
        let installDate = date("2026-05-01 10:00")
        service(now: installDate).bootstrap()

        let firstShow = service(now: date("2026-05-22 10:00"))
        firstShow.recordPositiveEvent()
        firstShow.recordPositiveEvent()
        XCTAssertTrue(firstShow.shouldPresent)
        firstShow.markPresented()

        // 30 日後 — まだ 60 日経っていない（次バージョンでもない）
        let withinCooldown = service(now: date("2026-06-21 10:00"))
        withinCooldown.recordPositiveEvent()
        XCTAssertFalse(withinCooldown.shouldPresent)
    }

    func test_shouldPresent_isFalse_whenSameVersionAlreadyPrompted() {
        let installDate = date("2026-05-01 10:00")
        service(now: installDate).bootstrap()

        let first = service(now: date("2026-05-22 10:00"), version: "0.1.0")
        first.recordPositiveEvent()
        first.recordPositiveEvent()
        first.markPresented()

        // クールダウンは過ぎているがバージョン据え置き → 再表示しない
        let later = service(now: date("2026-09-01 10:00"), version: "0.1.0")
        later.recordPositiveEvent()
        XCTAssertFalse(later.shouldPresent)
    }

    func test_shouldPresent_becomesTrueAgain_onNewVersionAfterCooldown() {
        let installDate = date("2026-05-01 10:00")
        service(now: installDate).bootstrap()

        let first = service(now: date("2026-05-22 10:00"), version: "0.1.0")
        first.recordPositiveEvent()
        first.recordPositiveEvent()
        first.markPresented()

        let nextVersion = service(now: date("2026-09-01 10:00"), version: "0.2.0")
        nextVersion.recordPositiveEvent()
        XCTAssertTrue(nextVersion.shouldPresent)
    }

    func test_shouldPresent_isFalse_afterLifetimeCapReached() {
        let installDate = date("2026-01-01 10:00")
        service(now: installDate).bootstrap()

        // 3 回まで依頼可能（cap = 3）
        for (i, day) in ["2026-01-22 10:00", "2026-04-01 10:00", "2026-07-01 10:00"].enumerated() {
            let s = service(now: date(day), version: "0.\(i + 1).0")
            s.recordPositiveEvent()
            s.recordPositiveEvent()
            XCTAssertTrue(s.shouldPresent, "依頼 #\(i + 1) は表示できるはず")
            s.markPresented()
        }

        // 4 回目: 別バージョン・クールダウン経過済みでも cap 到達で出ない
        let fourth = service(now: date("2026-10-01 10:00"), version: "0.4.0")
        fourth.recordPositiveEvent()
        fourth.recordPositiveEvent()
        XCTAssertFalse(fourth.shouldPresent, "ライフタイム上限後は表示されない")
    }

    // MARK: - State updates on markPresented

    func test_markPresented_updatesCountersAndDate() {
        let installDate = date("2026-05-01 10:00")
        service(now: installDate).bootstrap()

        let now = date("2026-05-22 10:00")
        let s = service(now: now, version: "0.1.0")
        s.recordPositiveEvent()
        s.recordPositiveEvent()
        s.markPresented()

        XCTAssertEqual(defaults.integer(forKey: "twinmirror.review.promptCount"), 1)
        XCTAssertEqual(defaults.string(forKey: "twinmirror.review.promptedVersion"), "0.1.0")
        XCTAssertEqual(
            defaults.double(forKey: "twinmirror.review.lastPromptDate"),
            now.timeIntervalSince1970
        )
        XCTAssertFalse(s.shouldPresent, "提示完了後は閉じている")
    }

    // MARK: - Dismiss

    func test_dismiss_clearsShouldPresentFlag() {
        let installDate = date("2026-05-01 10:00")
        service(now: installDate).bootstrap()

        let s = service(now: date("2026-05-22 10:00"))
        s.recordPositiveEvent()
        s.recordPositiveEvent()
        XCTAssertTrue(s.shouldPresent)

        s.dismiss()
        XCTAssertFalse(s.shouldPresent)
    }
}
