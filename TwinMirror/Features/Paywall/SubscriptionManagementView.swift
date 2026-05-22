import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// RevenueCatUI の `CustomerCenterView` を `.sheet` で提示するためのラッパー。
/// サブスクリプションの確認・解約・プラン変更などを 1 行で組み込める。
struct SubscriptionManagementView: View {
    var body: some View {
        #if canImport(RevenueCatUI)
        CustomerCenterView()
        #else
        Text("サブスクリプション管理を利用できません")
            .padding()
        #endif
    }
}
