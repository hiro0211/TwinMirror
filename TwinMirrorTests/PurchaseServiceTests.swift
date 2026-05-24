import XCTest
@testable import TwinMirror

final class PurchaseServiceTests: XCTestCase {

    func test_premiumEntitlementID_matchesDashboardIdentifier() {
        // RevenueCat ダッシュボードで設定する Entitlement 識別子と完全一致させる必要があるため、
        // ハードコード値を契約として検証する。
        XCTAssertEqual(PurchaseService.premiumEntitlementID, "premium")
    }

    func test_isPremium_isFalse_whenCustomerInfoIsNil() {
        XCTAssertFalse(PurchaseService.isPremium(in: nil))
    }

    @MainActor
    func test_shared_initialState_isNotPremium() {
        // SDK 起動直後（customerInfo がまだストリームから届いていない）は非加入扱い。
        // bootstrap() を呼ばずにアクセスしても安全であることを保証する。
        let service = PurchaseService.shared
        XCTAssertFalse(service.isPremium)
    }

    @MainActor
    func test_bootstrap_isIdempotent() {
        // 2 回呼ばれても Purchases.configure を二重実行しないこと。
        // 副作用が無いことだけを軽く検証（クラッシュしないなら OK）。
        PurchaseService.shared.bootstrap()
        PurchaseService.shared.bootstrap()
    }

    #if DEBUG
    @MainActor
    func test_debugEntitlementSummary_includesExpectedID_andIsPremiumFlag() {
        // 課金後に isPremium が反映されない問題の切り分け用デバッグ文字列。
        // 期待 entitlement ID と isPremium 状態が常に含まれていることを保証する。
        let summary = PurchaseService.shared.debugEntitlementSummary
        XCTAssertTrue(summary.contains("premium"),
                      "Expected entitlement ID must appear in debug summary: \(summary)")
        XCTAssertTrue(summary.contains("isPremium"),
                      "isPremium flag must appear in debug summary: \(summary)")
    }
    #endif
}
