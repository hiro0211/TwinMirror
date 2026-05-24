import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

/// TwinMirror プレミアムの購入導線。
/// 参考レイアウト: ヘッダー → 課金周期タブ → 割引バナー → 機能比較表 → スティッキーCTA。
/// 比較表の機能順は `docs/paywall.md` 章4「課金メリット優先順位」に準拠。
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
                        planTabs
                        savingsBanner
                        comparisonTable
                        secondaryActions
                        legalFooter
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.m)
                }

                if viewModel.isPurchasing || viewModel.isRestoring {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView(viewModel.isRestoring ? "復元中…" : "購入処理中…")
                        .padding(Theme.Spacing.l)
                        .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.medium))
                }
            }
            .safeAreaInset(edge: .bottom) {
                stickyCTA
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.Colors.textSecondary.opacity(0.6))
                    }
                    .accessibilityLabel("閉じる")
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
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.25))
                    .frame(width: 76, height: 76)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
            Text("TwinMirror Premium")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("年齢進行と全履歴で、未来の姿をもっと深く。")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var planTabs: some View {
        #if canImport(RevenueCat)
        let available = orderedTabPackages()
        if !available.isEmpty {
            PlanPeriodTabs(
                packages: available,
                selectedID: selectedPackageID,
                onSelect: { selectedPackageID = $0 }
            )
        }
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var savingsBanner: some View {
        #if canImport(RevenueCat)
        if let pkg = selectedPackage(), let info = savingsInfo(for: pkg) {
            SavingsBanner(percent: info.percent, perDayLabel: info.perDay)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        #endif
    }

    private var comparisonTable: some View {
        ComparisonTable()
    }

    @ViewBuilder
    private var stickyCTA: some View {
        VStack(spacing: 0) {
            #if canImport(RevenueCat)
            let pkg = selectedPackage()
            GlassButton(
                isProminent: true,
                isEnabled: pkg != nil && !viewModel.isPurchasing
            ) {
                guard let pkg else { return }
                Task { await viewModel.purchase(pkg) }
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "crown.fill")
                    Text("Premiumを始める")
                    if let pkg {
                        Text("—")
                            .opacity(0.7)
                        Text(ctaPriceLabel(for: pkg))
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.s)
            #endif
        }
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0), Color.white.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
    }

    // MARK: - Helpers

    #if canImport(RevenueCat)
    private func defaultSelectedPackageID() -> String? {
        guard let packages = purchaseService.currentOffering?.availablePackages else { return nil }
        if let yearly = packages.first(where: { $0.packageType == .annual }) { return yearly.identifier }
        if let monthly = packages.first(where: { $0.packageType == .monthly }) { return monthly.identifier }
        return packages.first?.identifier
    }

    private func selectedPackage() -> Package? {
        guard let id = selectedPackageID else { return nil }
        return purchaseService.currentOffering?.availablePackages.first { $0.identifier == id }
    }

    /// タブに並べる週/月/年プラン（存在するもののみ、その順序で）。
    private func orderedTabPackages() -> [Package] {
        guard let packages = purchaseService.currentOffering?.availablePackages else { return [] }
        let order: [PackageType] = [.weekly, .monthly, .annual]
        return order.compactMap { type in packages.first(where: { $0.packageType == type }) }
    }

    private func weeklyReferencePrice() -> Decimal? {
        purchaseService.currentOffering?.availablePackages
            .first(where: { $0.packageType == .weekly })?
            .storeProduct.price
    }

    /// 選択中プランの「週額換算 vs 週額プラン実勢価格」から割引率と日割り表示を算出。
    /// 週額プラン選択時、または比較対象の週額プランが存在しない時は nil。
    private func savingsInfo(for package: Package) -> (percent: Int, perDay: String)? {
        guard package.packageType != .weekly,
              let weekly = weeklyReferencePrice() else { return nil }

        let weeksPerPeriod: Decimal
        let daysPerPeriod: Decimal
        switch package.packageType {
        case .annual:
            weeksPerPeriod = 52
            daysPerPeriod = 365
        case .monthly:
            weeksPerPeriod = Decimal(string: "4.33") ?? 4
            daysPerPeriod = 30
        default:
            return nil
        }

        let price = package.storeProduct.price
        guard weeksPerPeriod > 0, daysPerPeriod > 0, weekly > 0 else { return nil }

        let perWeek = price / weeksPerPeriod
        let percentDecimal = (weekly - perWeek) / weekly * 100
        let percent = max(0, Int(NSDecimalNumber(decimal: percentDecimal).doubleValue.rounded()))
        guard percent >= 1 else { return nil }

        let perDay = price / daysPerPeriod
        let formatter = package.storeProduct.priceFormatter ?? {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.locale = .current
            return f
        }()
        let perDayString = formatter.string(from: NSDecimalNumber(decimal: perDay)) ?? "—"

        return (percent, perDayString)
    }

    private func ctaPriceLabel(for package: Package) -> String {
        let price = package.localizedPriceString
        switch package.packageType {
        case .weekly:  return "\(price)/週"
        case .monthly: return "\(price)/月"
        case .annual:  return "\(price)/年"
        case .lifetime: return price
        default:       return price
        }
    }
    #endif
}

// MARK: - Subviews

#if canImport(RevenueCat)
private struct PlanPeriodTabs: View {
    let packages: [Package]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(packages, id: \.identifier) { pkg in
                let isSelected = pkg.identifier == selectedID
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        onSelect(pkg.identifier)
                    }
                } label: {
                    Text(label(for: pkg))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            if isSelected {
                                Capsule().fill(Theme.Gradients.ctaButton)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.regularMaterial, in: .capsule)
    }

    private func label(for package: Package) -> String {
        switch package.packageType {
        case .weekly:  return "週"
        case .monthly: return "月"
        case .annual:  return "年"
        case .lifetime: return "買い切り"
        default:       return package.storeProduct.localizedTitle
        }
    }
}

private struct SavingsBanner: View {
    let percent: Int
    let perDayLabel: String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image(systemName: "tag.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.primaryDeep)
            Text("週額より約\(percent)%お得")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Colors.primaryDeep)
            Spacer(minLength: Theme.Spacing.s)
            Text("約\(perDayLabel)/日")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.75))
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Theme.Colors.primary.opacity(0.3))
        )
    }
}
#endif

// MARK: - Comparison Table

private enum PremiumValue {
    case text(String)
    case check
}

private struct FeatureRowData {
    let icon: String
    let title: String
    let free: String
    let premium: PremiumValue
}

private struct ComparisonTable: View {

    private static let rows: [FeatureRowData] = [
        .init(icon: "figure.child", title: "年齢シミュレーション", free: "5・10歳のみ", premium: .text("0〜20歳")),
        .init(icon: "clock.arrow.circlepath", title: "履歴保存", free: "直近2件のみ", premium: .text("全件 永久保存")),
        .init(icon: "square.grid.2x2.fill", title: "3パターン同時生成", free: "—", premium: .check),
        .init(icon: "drop.fill", title: "ウォーターマーク", free: "あり", premium: .text("なし")),
        .init(icon: "4k.tv", title: "画質", free: "標準 (1K)", premium: .text("4K HD")),
        .init(icon: "bolt.fill", title: "Fast 生成", free: "2回/日", premium: .text("無制限")),
        .init(icon: "rectangle.slash.fill", title: "広告非表示", free: "—", premium: .check)
    ]

    private static let freeColumnWidth: CGFloat = 80
    private static let premiumColumnWidth: CGFloat = 92
    private static let highlightColor = Theme.Colors.primary.opacity(0.22)
    private static let dividerColor = Color.gray.opacity(0.18)

    var body: some View {
        Grid(alignment: .center, horizontalSpacing: 0, verticalSpacing: 0) {
            headerRow
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { idx, data in
                featureRow(data: data, isFirst: idx == 0)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium)
                .strokeBorder(Theme.Colors.primary.opacity(0.4), lineWidth: 1)
        )
    }

    private var headerRow: some View {
        GridRow {
            // 機能名列（空ヘッダー）
            Color.clear
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            // Free 列
            Text("Free")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: Self.freeColumnWidth)
                .padding(.vertical, 14)

            // Premium 列（ハイライト背景）
            VStack(spacing: 2) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Colors.primaryDeep)
                Text("Premium")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.primaryDeep)
            }
            .frame(width: Self.premiumColumnWidth)
            .padding(.vertical, 12)
            .background(Self.highlightColor)
        }
    }

    @ViewBuilder
    private func featureRow(data: FeatureRowData, isFirst: Bool) -> some View {
        GridRow {
            // 機能名セル
            HStack(spacing: 8) {
                Image(systemName: data.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primaryDeep)
                    .frame(width: 20)
                Text(data.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.leading, Theme.Spacing.m)
            .padding(.trailing, 8)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { topDivider(visible: !isFirst) }

            // Free セル
            Text(data.free)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: Self.freeColumnWidth)
                .padding(.vertical, 12)
                .overlay(alignment: .top) { topDivider(visible: !isFirst) }

            // Premium セル（ハイライト背景）
            premiumCell(data.premium)
                .frame(width: Self.premiumColumnWidth)
                .padding(.vertical, 12)
                .background(Self.highlightColor)
                .overlay(alignment: .top) { topDivider(visible: !isFirst) }
        }
    }

    @ViewBuilder
    private func premiumCell(_ value: PremiumValue) -> some View {
        switch value {
        case .text(let text):
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.Colors.primaryDeep)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 6)
        case .check:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.Colors.primaryDeep)
        }
    }

    @ViewBuilder
    private func topDivider(visible: Bool) -> some View {
        if visible {
            Rectangle()
                .fill(Self.dividerColor)
                .frame(height: 0.5)
        }
    }
}
