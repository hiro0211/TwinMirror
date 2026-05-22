import Foundation
#if canImport(RevenueCat)
import RevenueCat
#endif

/// PaywallView の購入フローを駆動する ViewModel。
/// `PurchaseService.shared` を裏で呼び、進行中フラグ・エラー表示用文字列を提供する。
@Observable
@MainActor
final class PaywallViewModel {

    var isPurchasing: Bool = false
    var isRestoring: Bool = false
    var errorMessage: String?

    private let analytics: AnalyticsTracking

    init(analytics: AnalyticsTracking = DefaultAnalytics.shared) {
        self.analytics = analytics
    }

    #if canImport(RevenueCat)

    /// 指定 Package を購入する。キャンセル時はエラー表示しない。
    func purchase(_ package: Package) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        do {
            let result = try await PurchaseService.shared.purchase(package)
            if !result.userCancelled {
                analytics.track(.purchaseCompleted(packageID: package.identifier))
            }
        } catch {
            if let rcError = error as? RevenueCat.ErrorCode, rcError == .purchaseCancelledError {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    /// 過去の購入を復元する。
    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        errorMessage = nil

        do {
            _ = try await PurchaseService.shared.restorePurchases()
            analytics.track(.restoreCompleted(wasPremium: PurchaseService.shared.isPremium))
            if !PurchaseService.shared.isPremium {
                errorMessage = "復元できる購入が見つかりませんでした。"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif
}
