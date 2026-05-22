import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

/// TwinMirror プレミアムの購入導線。
/// `PurchaseService.shared.currentOffering` から表示する Package を読み、
/// 購入完了時（`isPremium = true`）に自動で閉じる。
struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss

    private let purchaseService = PurchaseService.shared
    @State private var viewModel: PaywallViewModel
    @State private var selectedPackageID: String?
    @State private var showManageSubscription = false

    private let analytics: AnalyticsTracking
    private let source: String

    init(
        source: String = "unknown",
        analytics: AnalyticsTracking = DefaultAnalytics.shared
    ) {
        self.source = source
        self.analytics = analytics
        _viewModel = State(initialValue: PaywallViewModel(analytics: analytics))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Gradients.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.l) {
                        header
                        benefits
                        packageList
                        purchaseButton
                        secondaryActions
                        legalFooter
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.vertical, Theme.Spacing.l)
                }

                if viewModel.isPurchasing || viewModel.isRestoring {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView(viewModel.isRestoring ? "復元中…" : "購入処理中…")
                        .padding(Theme.Spacing.l)
                        .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.medium))
                }
            }
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                #if canImport(RevenueCat)
                if purchaseService.currentOffering == nil {
                    await purchaseService.refreshOfferings()
                }
                selectedPackageID = defaultSelectedPackageID()
                #endif
                analytics.track(.paywallShown(source: source))
            }
            .onChange(of: purchaseService.isPremium) { _, newValue in
                if newValue { dismiss() }
            }
            .alert("エラー", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showManageSubscription) {
                SubscriptionManagementView()
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: "sparkles")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryDeep)
            Text("TwinMirror Premium")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("プレミアム生成を1日上限なく、もっと多くの未来の姿に出会えます。")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.m)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            BenefitRow(icon: "infinity", text: "プレミアム生成が1日無制限")
            BenefitRow(icon: "wand.and.stars", text: "より自然で高品質な合成画像")
            BenefitRow(icon: "person.2.fill", text: "今後追加されるプレミアム機能をすべて利用可能")
        }
        .padding(Theme.Spacing.m)
        .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.medium))
    }

    @ViewBuilder
    private var packageList: some View {
        #if canImport(RevenueCat)
        if let packages = purchaseService.currentOffering?.availablePackages, !packages.isEmpty {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(orderedPackages(from: packages), id: \.identifier) { package in
                    PackageCard(
                        package: package,
                        isSelected: selectedPackageID == package.identifier,
                        isBestValue: isYearly(package),
                        action: { selectedPackageID = package.identifier }
                    )
                }
            }
        } else {
            VStack(spacing: Theme.Spacing.s) {
                ProgressView()
                Text("プランを読み込んでいます…")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Button("再読み込み") {
                    Task { await purchaseService.refreshOfferings() }
                }
                .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.l)
            .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.medium))
        }
        #else
        Text("RevenueCat が利用できないビルドです。")
            .font(.system(size: 13))
            .foregroundStyle(Theme.Colors.textSecondary)
        #endif
    }

    @ViewBuilder
    private var purchaseButton: some View {
        #if canImport(RevenueCat)
        let pkg = selectedPackage()
        GlassButton(
            isProminent: true,
            isEnabled: pkg != nil && !viewModel.isPurchasing,
            action: {
                guard let pkg else { return }
                Task { await viewModel.purchase(pkg) }
            }
        ) {
            Text(buttonTitle(for: pkg))
        }
        #else
        EmptyView()
        #endif
    }

    private var secondaryActions: some View {
        HStack(spacing: Theme.Spacing.l) {
            Button("購入を復元") {
                #if canImport(RevenueCat)
                Task { await viewModel.restore() }
                #endif
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.Colors.textSecondary)

            Button("サブスクリプション管理") {
                showManageSubscription = true
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var legalFooter: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("自動更新サブスクリプションです。期間終了の24時間前までに解約しない場合、同額で自動更新されます。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: Theme.Spacing.m) {
                Link("利用規約", destination: AppConfig.termsURL)
                Text("・").foregroundStyle(Theme.Colors.textSecondary)
                Link("プライバシーポリシー", destination: AppConfig.privacyURL)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Helpers

    #if canImport(RevenueCat)
    private func defaultSelectedPackageID() -> String? {
        guard let packages = purchaseService.currentOffering?.availablePackages else { return nil }
        if let yearly = packages.first(where: { $0.packageType == .annual }) { return yearly.identifier }
        return packages.first?.identifier
    }

    private func selectedPackage() -> Package? {
        guard let id = selectedPackageID else { return nil }
        return purchaseService.currentOffering?.availablePackages.first { $0.identifier == id }
    }

    private func orderedPackages(from packages: [Package]) -> [Package] {
        // 年額を先頭に固定し、その後に月額・他を並べる。
        let yearly = packages.filter { $0.packageType == .annual }
        let monthly = packages.filter { $0.packageType == .monthly }
        let others = packages.filter { $0.packageType != .annual && $0.packageType != .monthly }
        return yearly + monthly + others
    }

    private func isYearly(_ package: Package) -> Bool {
        package.packageType == .annual
    }

    private func buttonTitle(for package: Package?) -> String {
        guard let package else { return "プランを選択してください" }
        return "\(package.localizedPriceString) で購入する"
    }
    #endif
}

// MARK: - Subviews

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.primaryDeep)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer(minLength: 0)
        }
    }
}

#if canImport(RevenueCat)
private struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.Colors.primaryDeep : Theme.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.s) {
                        Text(displayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        if isBestValue {
                            Text("ベストバリュー")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.primaryDeep, in: .capsule)
                                .foregroundStyle(.white)
                        }
                    }
                    Text(priceLine)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                Text(package.localizedPriceString)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(Theme.Spacing.m)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(
                        isSelected ? Theme.Colors.primaryDeep : Color.clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var displayTitle: String {
        switch package.packageType {
        case .annual:  return "年額プラン"
        case .monthly: return "月額プラン"
        case .weekly:  return "週額プラン"
        case .lifetime: return "買い切り"
        default:       return package.storeProduct.localizedTitle
        }
    }

    private var priceLine: String {
        switch package.packageType {
        case .annual:  return "年に1度のお支払い"
        case .monthly: return "毎月自動更新"
        case .weekly:  return "毎週自動更新"
        case .lifetime: return "1度きりの購入"
        default:       return package.storeProduct.localizedDescription
        }
    }
}
#endif
