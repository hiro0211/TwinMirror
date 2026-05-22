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
        UsageLimiter(defaults: defaults, now: { now }, bypassLimit: false)
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

    // MARK: - Premium counter (separate from fast)

    func test_premium_initialFreeRemainingIs1() {
        let l = limiter(now: date("2026-05-20 10:00"))
        XCTAssertEqual(l.remainingPremiumToday, UsageLimiter.premiumDailyLimitFree)
        XCTAssertTrue(l.canGeneratePremium)
    }

    func test_premium_consumeBeyondFreeLimit_fails() {
        let l = limiter(now: date("2026-05-20 10:00"))
        XCTAssertTrue(l.tryConsume(mode: .premium))
        XCTAssertFalse(l.tryConsume(mode: .premium), "非課金ユーザーは1日1回まで")
        XCTAssertEqual(l.remainingPremiumToday, 0)
    }

    func test_premium_independentFromFast() {
        let l = limiter(now: date("2026-05-20 10:00"))
        // fastを3回消費してもpremiumには影響しない
        _ = l.tryConsume(mode: .fast)
        _ = l.tryConsume(mode: .fast)
        _ = l.tryConsume(mode: .fast)
        XCTAssertEqual(l.remainingFastToday, 0)
        XCTAssertEqual(l.remainingPremiumToday, UsageLimiter.premiumDailyLimitFree)
        XCTAssertTrue(l.canGeneratePremium)
    }

    func test_fast_independentFromPremium() {
        let l = limiter(now: date("2026-05-20 10:00"))
        _ = l.tryConsume(mode: .premium)
        XCTAssertEqual(l.remainingPremiumToday, 0)
        XCTAssertEqual(l.remainingFastToday, UsageLimiter.fastDailyLimit)
        XCTAssertTrue(l.canGenerateFast)
    }

    func test_premium_resetsOnNextDay() {
        let l1 = limiter(now: date("2026-05-20 23:00"))
        _ = l1.tryConsume(mode: .premium)
        XCTAssertEqual(l1.remainingPremiumToday, 0)

        let l2 = limiter(now: date("2026-05-21 00:01"))
        XCTAssertEqual(l2.remainingPremiumToday, UsageLimiter.premiumDailyLimitFree)
    }

    // MARK: - Development bypass

    private func unlimitedLimiter(now: Date) -> UsageLimiter {
        UsageLimiter(defaults: defaults, now: { now }, bypassLimit: true)
    }

    func test_bypassLimit_fast_neverExhausts() {
        let l = unlimitedLimiter(now: date("2026-05-20 10:00"))
        for _ in 0..<10 {
            XCTAssertTrue(l.tryConsume(mode: .fast))
        }
        XCTAssertTrue(l.canGenerateFast)
        XCTAssertEqual(l.remainingFastToday, UsageLimiter.fastDailyLimit)
    }

    func test_bypassLimit_premium_neverExhausts() {
        let l = unlimitedLimiter(now: date("2026-05-20 10:00"))
        for _ in 0..<10 {
            XCTAssertTrue(l.tryConsume(mode: .premium))
        }
        XCTAssertTrue(l.canGeneratePremium)
        XCTAssertEqual(l.remainingPremiumToday, UsageLimiter.premiumDailyLimitFree)
    }

    func test_bypassLimit_doesNotPersistCount() {
        let l1 = unlimitedLimiter(now: date("2026-05-20 10:00"))
        _ = l1.tryConsume(mode: .fast)
        _ = l1.tryConsume(mode: .premium)
        // bypass 中は永続化しないので、通常の Limiter から見ても 0 消費のまま
        let l2 = limiter(now: date("2026-05-20 11:00"))
        XCTAssertEqual(l2.remainingFastToday, UsageLimiter.fastDailyLimit)
        XCTAssertEqual(l2.remainingPremiumToday, UsageLimiter.premiumDailyLimitFree)
    }

    func test_premium_subscriberHasMuchHigherLimit() {
        let fixedNow = date("2026-05-20 10:00")
        let l = UsageLimiter(
            defaults: defaults,
            now: { fixedNow },
            isPremiumSubscriber: { true },
            bypassLimit: false
        )
        XCTAssertEqual(l.remainingPremiumToday, UsageLimiter.premiumDailyLimitSubscribed)
        // 加入者は1日1回の制限を受けない
        XCTAssertTrue(l.tryConsume(mode: .premium))
        XCTAssertTrue(l.tryConsume(mode: .premium))
        XCTAssertTrue(l.canGeneratePremium)
    }
}
