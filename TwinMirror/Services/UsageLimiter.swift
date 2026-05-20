import Foundation

/// 1日あたりの画像生成回数を UserDefaults で管理する。
/// TestFlight 配布時に Gemini API のコストが青天井にならないよう、
/// 端末ローカルで上限をかける。
///
/// 内部の UserDefaults は documented thread-safe であり、
/// 他に可変状態を持たないため `@unchecked Sendable`。
final class UsageLimiter: @unchecked Sendable {
    /// 1日あたりの生成上限。
    static let dailyLimit = 3

    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    private static let dateKey = "twinmirror.usage.date"
    private static let countKey = "twinmirror.usage.count"

    init(
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
            return c
        }()
    ) {
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
    }

    var remainingToday: Int {
        max(0, Self.dailyLimit - currentCount())
    }

    var canGenerate: Bool {
        remainingToday > 0
    }

    /// 1回消費を試みる。上限到達時は false を返す。
    @discardableResult
    func tryConsume() -> Bool {
        guard canGenerate else { return false }
        let next = currentCount() + 1
        defaults.set(todayKey(), forKey: Self.dateKey)
        defaults.set(next, forKey: Self.countKey)
        return true
    }

    private func currentCount() -> Int {
        guard defaults.string(forKey: Self.dateKey) == todayKey() else { return 0 }
        return defaults.integer(forKey: Self.countKey)
    }

    private func todayKey() -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension UsageLimiter {
    /// アプリ全体で共有するシングルトン。
    static let shared = UsageLimiter()
}
