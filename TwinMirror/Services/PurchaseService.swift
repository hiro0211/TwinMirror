import Foundation
import os
#if canImport(RevenueCat)
import RevenueCat
#endif

/// RevenueCat SDK のラッパー。
///
/// - 単一インスタンス（`shared`）で起動時に `bootstrap()` を呼び、
///   `Purchases.configure` を 1 回だけ実行する。
/// - `Purchases.shared.customerInfoStream` を購読し、最新の `CustomerInfo` を
///   `@MainActor` 上で保持する。
/// - `isPremium` はエンタイトルメント "TwinMirror Premium" のアクティブ状態を返す。
/// - `UsageLimiter` はこのプロパティをクロージャ経由で参照し、毎回 fresh な値を読む。
@MainActor
@Observable
final class PurchaseService {

    /// RevenueCat ダッシュボードの Entitlement 識別子と完全一致させる必要がある。
    /// このリテラルは契約の一部であり、テストでも検証している。
    nonisolated static let premiumEntitlementID = "TwinMirror Premium"

    static let shared = PurchaseService()

    private static let log = Logger(subsystem: "app.twinmirror.ios", category: "PurchaseService")

    private var didBootstrap = false

    #if canImport(RevenueCat)
    private(set) var customerInfo: CustomerInfo?
    private(set) var currentOffering: Offering?
    private var customerInfoTask: Task<Void, Never>?
    #endif

    private init() {}

    // MARK: - Bootstrap

    /// App 起動時に 1 回だけ呼ぶ。複数回呼ばれても安全。
    /// `AppConfig.revenueCatAPIKey` が空（xcconfig 未設定）の場合は no-op。
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        let key = AppConfig.revenueCatAPIKey
        guard !key.isEmpty else {
            Self.log.warning("REVENUECAT_API_KEY is empty — RevenueCat is disabled for this build.")
            return
        }

        #if canImport(RevenueCat)
        #if DEBUG
        Purchases.logLevel = .info
        #else
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(withAPIKey: key)
        startCustomerInfoStream()
        Task { await refreshOfferings() }
        #endif
    }

    // MARK: - Entitlement

    /// 現在の購入状態。`customerInfo` が未到達なら false。
    var isPremium: Bool {
        #if canImport(RevenueCat)
        return Self.isPremium(in: customerInfo)
        #else
        return false
        #endif
    }

    #if canImport(RevenueCat)
    /// 引数の `CustomerInfo` からエンタイトルメントのアクティブ状態を判定する純関数。
    /// テスト用に `nil` を受け付ける。
    nonisolated static func isPremium(in customerInfo: CustomerInfo?) -> Bool {
        customerInfo?.entitlements[premiumEntitlementID]?.isActive == true
    }
    #else
    nonisolated static func isPremium(in customerInfo: Any?) -> Bool { false }
    #endif

    // MARK: - Purchases

    #if canImport(RevenueCat)
    /// Offering を取得・更新する。`currentOffering` を populate する。
    func refreshOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            Self.log.error("Failed to fetch offerings: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 指定 `Package` を購入する。成功時は `customerInfo` が更新されストリームから配信される。
    /// `ErrorCode.purchaseCancelledError` の場合は呼び出し側でフィルタすること。
    @discardableResult
    func purchase(_ package: Package) async throws -> PurchaseResultData {
        let result = try await Purchases.shared.purchase(package: package)
        customerInfo = result.customerInfo
        return result
    }

    /// 機種変更後などに購入を復元する。
    @discardableResult
    func restorePurchases() async throws -> CustomerInfo {
        let info = try await Purchases.shared.restorePurchases()
        customerInfo = info
        return info
    }

    // MARK: - Internals

    private func startCustomerInfoStream() {
        customerInfoTask?.cancel()
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self else { return }
                await MainActor.run {
                    self.customerInfo = info
                }
            }
        }
    }
    #endif
}
