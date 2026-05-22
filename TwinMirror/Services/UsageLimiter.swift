import Foundation

/// 1日あたりの画像生成回数を UserDefaults で管理する。
/// TestFlight 配布時に Gemini API のコストが青天井にならないよう、
/// 端末ローカルで上限をかける。
///
/// fast モードと premium モードはそれぞれ独立したカウンターを持つ。
/// IAP サブスクリプション加入者は `isPremiumSubscriber` で premium 制限を実質
/// 無効化できる（注入された判定クロージャで判定）。
///
/// 内部の UserDefaults は documented thread-safe であり、
/// 他に可変状態を持たないため `@unchecked Sendable`。
final class UsageLimiter: @unchecked Sendable {
    /// fast モードの1日あたり上限。
    static let fastDailyLimit = 3
    /// premium モードの非課金ユーザー向け1日あたり上限。
    static let premiumDailyLimitFree = 1
    /// IAP サブスクリプション加入者向けの premium 上限（実質無制限相当）。
    static let premiumDailyLimitSubscribed = 1000

    /// 旧 `dailyLimit` 互換シンボル（fast 上限と同義）。既存テスト用。
    static var dailyLimit: Int { fastDailyLimit }

    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let isPremiumSubscriber: @Sendable () -> Bool
    private let bypassLimit: Bool

    private static let fastDateKey = "twinmirror.usage.date"
    private static let fastCountKey = "twinmirror.usage.count"
    private static let premiumDateKey = "twinmirror.usage.premium.date"
    private static let premiumCountKey = "twinmirror.usage.premium.count"

    /// Xcode 経由でビルドした開発ビルド（Debug 構成）では利用制限を無効化する。
    /// TestFlight / App Store 配布の Release ビルドでは false。
    static var defaultBypassLimit: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    init(
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current
            return c
        }(),
        isPremiumSubscriber: @escaping @Sendable () -> Bool = { false },
        bypassLimit: Bool = UsageLimiter.defaultBypassLimit
    ) {
        self.defaults = defaults
        self.now = now
        self.calendar = calendar
        self.isPremiumSubscriber = isPremiumSubscriber
        self.bypassLimit = bypassLimit
    }

    // MARK: - Fast

    var remainingFastToday: Int {
        if bypassLimit { return Self.fastDailyLimit }
        return max(0, Self.fastDailyLimit - fastCount())
    }

    /// 旧 API 互換: fast の残量を返す。
    var remainingToday: Int { remainingFastToday }

    var canGenerateFast: Bool { remainingFastToday > 0 }

    /// 旧 API 互換: fast 用カウンタが残っているか。
    var canGenerate: Bool { canGenerateFast }

    // MARK: - Premium

    var premiumDailyLimit: Int {
        isPremiumSubscriber() ? Self.premiumDailyLimitSubscribed : Self.premiumDailyLimitFree
    }

    var remainingPremiumToday: Int {
        if bypassLimit { return Self.premiumDailyLimitFree }
        return max(0, premiumDailyLimit - premiumCount())
    }

    var canGeneratePremium: Bool { remainingPremiumToday > 0 }

    // MARK: - Consumption

    /// モード別に1回消費を試みる。上限到達時は false を返す。
    @discardableResult
    func tryConsume(mode: GenerationMode) -> Bool {
        switch mode {
        case .fast:    return tryConsumeFast()
        case .premium: return tryConsumePremium()
        }
    }

    /// 旧 API 互換: fast 消費。
    @discardableResult
    func tryConsume() -> Bool {
        tryConsumeFast()
    }

    // MARK: - Internals

    private func tryConsumeFast() -> Bool {
        if bypassLimit { return true }
        guard canGenerateFast else { return false }
        let next = fastCount() + 1
        defaults.set(todayKey(), forKey: Self.fastDateKey)
        defaults.set(next, forKey: Self.fastCountKey)
        return true
    }

    private func tryConsumePremium() -> Bool {
        if bypassLimit { return true }
        guard canGeneratePremium else { return false }
        let next = premiumCount() + 1
        defaults.set(todayKey(), forKey: Self.premiumDateKey)
        defaults.set(next, forKey: Self.premiumCountKey)
        return true
    }

    private func fastCount() -> Int {
        guard defaults.string(forKey: Self.fastDateKey) == todayKey() else { return 0 }
        return defaults.integer(forKey: Self.fastCountKey)
    }

    private func premiumCount() -> Int {
        guard defaults.string(forKey: Self.premiumDateKey) == todayKey() else { return 0 }
        return defaults.integer(forKey: Self.premiumCountKey)
    }

    private func todayKey() -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

extension UsageLimiter {
    /// アプリ全体で共有するシングルトン。
    /// `PurchaseService.shared.isPremium` をクロージャ経由で参照することで、
    /// 購入直後にカウンタ閾値（1/日 → 1000/日）が即座に切り替わる。
    static let shared = UsageLimiter(
        isPremiumSubscriber: { MainActor.assumeIsolated { PurchaseService.shared.isPremium } }
    )
}
