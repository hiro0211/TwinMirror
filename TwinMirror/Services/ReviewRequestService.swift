import Foundation
import SwiftUI

/// App Store レビュー依頼モーダルの表示判定と状態永続化を担う。
///
/// 表示条件（すべて満たす場合のみ `shouldPresent = true`）:
/// - インストールから 3 日以上経過
/// - 累計のポジティブイベント（保存成功）数が 2 回以上
/// - 直近の依頼から 60 日以上経過（クールダウン）
/// - 現在の `CFBundleShortVersionString` で未依頼
/// - 累計依頼回数が `lifetimePromptCap` 未満
///
/// Apple のレート制限（365日に3回）も二重で安全側に倒すため `lifetimePromptCap = 3`。
@MainActor
@Observable
final class ReviewRequestService {

    /// インストール後この日数経過したユーザーにだけ依頼する。
    static let minInstallDays: Int = 3
    /// 累計でこの回数のポジティブイベント（保存成功）後に依頼を試みる。
    static let minPositiveEvents: Int = 2
    /// 直近の依頼からこの日数のクールダウンを置く。
    static let cooldownDays: Int = 60
    /// アプリ生涯で依頼する上限回数（Apple のレート制限と合わせる）。
    static let lifetimePromptCap: Int = 3

    static let shared = ReviewRequestService()

    // MARK: - Storage keys

    private static let installDateKey = "twinmirror.review.installDate"
    private static let successCountKey = "twinmirror.review.successCount"
    private static let lastPromptDateKey = "twinmirror.review.lastPromptDate"
    private static let promptCountKey = "twinmirror.review.promptCount"
    private static let promptedVersionKey = "twinmirror.review.promptedVersion"

    // MARK: - Observable state

    private(set) var shouldPresent: Bool = false

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let now: @Sendable () -> Date
    private let bundleShortVersion: String

    init(
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = { Date() },
        bundleShortVersion: String = ReviewRequestService.defaultShortVersion()
    ) {
        self.defaults = defaults
        self.now = now
        self.bundleShortVersion = bundleShortVersion
    }

    nonisolated private static func defaultShortVersion() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }

    // MARK: - Public API

    /// アプリ起動時に呼ぶ。初回起動時のインストール日時を記録する。
    func bootstrap() {
        if defaults.double(forKey: Self.installDateKey) == 0 {
            defaults.set(now().timeIntervalSince1970, forKey: Self.installDateKey)
        }
    }

    /// 保存成功などのポジティブイベントを記録し、表示条件を満たせばモーダル表示フラグを立てる。
    func recordPositiveEvent() {
        let next = defaults.integer(forKey: Self.successCountKey) + 1
        defaults.set(next, forKey: Self.successCountKey)
        requestPresentationIfEligible()
    }

    /// 表示条件を満たせば `shouldPresent = true` に。
    func requestPresentationIfEligible() {
        guard isEligible() else { return }
        shouldPresent = true
    }

    /// モーダルが実際に表示されたタイミングで呼ぶ。再表示までのカウンタを更新する。
    func markPresented() {
        let nowDate = now()
        defaults.set(nowDate.timeIntervalSince1970, forKey: Self.lastPromptDateKey)
        defaults.set(defaults.integer(forKey: Self.promptCountKey) + 1, forKey: Self.promptCountKey)
        defaults.set(bundleShortVersion, forKey: Self.promptedVersionKey)
        shouldPresent = false
    }

    /// モーダルをユーザーが閉じたなど、フラグだけ降ろす場合に使う。
    func dismiss() {
        shouldPresent = false
    }

    // MARK: - Eligibility logic

    private func isEligible() -> Bool {
        // Lifetime cap
        if defaults.integer(forKey: Self.promptCountKey) >= Self.lifetimePromptCap {
            return false
        }
        // Same-version guard
        if let last = defaults.string(forKey: Self.promptedVersionKey),
           last == bundleShortVersion {
            return false
        }
        // Install age
        let installEpoch = defaults.double(forKey: Self.installDateKey)
        guard installEpoch > 0 else { return false }
        let installDate = Date(timeIntervalSince1970: installEpoch)
        let elapsedDays = now().timeIntervalSince(installDate) / 86_400
        if elapsedDays < Double(Self.minInstallDays) {
            return false
        }
        // Cooldown since last prompt
        let lastEpoch = defaults.double(forKey: Self.lastPromptDateKey)
        if lastEpoch > 0 {
            let lastDate = Date(timeIntervalSince1970: lastEpoch)
            let sinceLast = now().timeIntervalSince(lastDate) / 86_400
            if sinceLast < Double(Self.cooldownDays) {
                return false
            }
        }
        // Positive events threshold
        if defaults.integer(forKey: Self.successCountKey) < Self.minPositiveEvents {
            return false
        }
        return true
    }
}
