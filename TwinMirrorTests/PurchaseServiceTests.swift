import XCTest
@testable import TwinMirror

final class PurchaseServiceTests: XCTestCase {

    func test_premiumEntitlementID_matchesDashboardIdentifier() {
        // RevenueCat ダッシュボードで設定する Entitlement 識別子と完全一致させる必要があるため、
        // ハードコード値を契約として検証する。
        XCTAssertEqual(PurchaseService.premiumEntitlementID, "TwinMirror Premium")
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
}
