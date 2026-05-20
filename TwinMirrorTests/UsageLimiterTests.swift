import XCTest
@testable import TwinMirror

final class UsageLimiterTests: XCTestCase {

    private let suiteName = "twinmirror.usage.tests"
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

    private func limiter(now: Date) -> UsageLimiter {
        UsageLimiter(defaults: defaults, now: { now })
    }

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    func test_initialRemainingEqualsLimit() {
        let l = limiter(now: date("2026-05-20 10:00"))
        XCTAssertEqual(l.remainingToday, UsageLimiter.dailyLimit)
    }

    func test_consumeDecrementsRemaining() {
        let l = limiter(now: date("2026-05-20 10:00"))
        XCTAssertTrue(l.tryConsume())
        XCTAssertEqual(l.remainingToday, 2)
        XCTAssertTrue(l.tryConsume())
        XCTAssertEqual(l.remainingToday, 1)
        XCTAssertTrue(l.tryConsume())
        XCTAssertEqual(l.remainingToday, 0)
    }

    func test_consumeBeyondLimitFails() {
        let l = limiter(now: date("2026-05-20 10:00"))
        _ = l.tryConsume()
        _ = l.tryConsume()
        _ = l.tryConsume()
        XCTAssertFalse(l.tryConsume(), "上限到達後の消費はfalseを返さなければならない")
        XCTAssertEqual(l.remainingToday, 0)
    }

    func test_resetsOnNextDay() {
        let l1 = limiter(now: date("2026-05-20 23:00"))
        _ = l1.tryConsume()
        _ = l1.tryConsume()
        _ = l1.tryConsume()
        XCTAssertEqual(l1.remainingToday, 0)

        let l2 = limiter(now: date("2026-05-21 00:01"))
        XCTAssertEqual(l2.remainingToday, UsageLimiter.dailyLimit, "翌日にカウントがリセットされる")
        XCTAssertTrue(l2.tryConsume())
    }

    func test_sameDayAcrossInstancesSharesCount() {
        let l1 = limiter(now: date("2026-05-20 10:00"))
        _ = l1.tryConsume()

        let l2 = limiter(now: date("2026-05-20 15:00"))
        XCTAssertEqual(l2.remainingToday, 2, "同日内なら別インスタンスでもカウントを共有")
    }

    func test_canGenerateMirrorsRemaining() {
        let l = limiter(now: date("2026-05-20 10:00"))
        XCTAssertTrue(l.canGenerate)
        _ = l.tryConsume()
        _ = l.tryConsume()
        _ = l.tryConsume()
        XCTAssertFalse(l.canGenerate)
    }
}
