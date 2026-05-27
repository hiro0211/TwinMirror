import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var purchaseService = PurchaseService.shared
    @State private var surveyService = OnboardingSurveyService.shared

    @State private var showPaywall = false
    @State private var showManageSubscription = false
    @State private var showSurvey = false
    @State private var showRestoreAlert = false
    @State private var restoreAlertMessage = ""
    @State private var isRestoring = false
    @State private var showClearConfirm = false
    @State private var showClearedToast = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Gradients.background.ignoresSafeArea()

                List {
                    premiumSection
                    supportSection
                    promoteSection
                    legalSection
                    dataSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)

                if isRestoring {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView("復元中…")
                        .padding(Theme.Spacing.l)
                        .background(.regularMaterial, in: .rect(cornerRadius: Theme.Radius.medium))
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView(source: "settings")
            }
            .sheet(isPresented: $showManageSubscription) {
                SubscriptionManagementView()
            }
            .sheet(isPresented: $showSurvey) {
                OnboardingSurveyView(service: surveyService)
            }
            .alert("購入の復元", isPresented: $showRestoreAlert) {
                Button("OK") { showRestoreAlert = false }
            } message: {
                Text(restoreAlertMessage)
            }
            .alert(isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Alert(
                    title: Text("エラー"),
                    message: Text(viewModel.errorMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
            .confirmationDialog(
                "履歴をすべて削除しますか？",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("すべて削除", role: .destructive) {
                    Task {
                        await viewModel.clearAllHistory()
                        if viewModel.didClearAll {
                            showClearedToast = true
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("クラウドに保存されたあなたの履歴がすべて削除されます。この操作は取り消せません。")
            }
            .alert("履歴を削除しました", isPresented: $showClearedToast) {
                Button("OK") { showClearedToast = false }
            }
        }
    }

    // MARK: - Premium

    private var premiumSection: some View {
        Section {
            HStack {
                Image(systemName: purchaseService.isPremium ? "checkmark.seal.fill" : "sparkles")
                    .foregroundStyle(purchaseService.isPremium ? Theme.Colors.primaryDeep : Theme.Colors.accent)
                Text(purchaseService.isPremium ? "Premium 契約中" : "Free プラン")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
            }

            if !purchaseService.isPremium {
                SettingsRow(
                    icon: "sparkles",
                    title: "Premium プランを見る",
                    action: { showPaywall = true }
                )
            }

            SettingsRow(
                icon: "arrow.clockwise",
                title: "購入を復元",
                action: { Task { await restorePurchases() } }
            )

            SettingsRow(
                icon: "creditcard",
                title: "サブスクリプションを管理",
                action: { showManageSubscription = true }
            )
        } header: {
            Text("Premium")
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section {
            NavigationLink {
                FAQView()
            } label: {
                Label {
                    Text("よくある質問 (FAQ)")
                        .foregroundStyle(Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Theme.Colors.accent)
                }
            }

            SettingsRow(
                icon: "envelope",
                title: "お問い合わせ",
                action: { openURL(Self.supportMailtoURL) }
            )
        } header: {
            Text("困ったとき")
        }
    }

    // MARK: - Promote

    private var promoteSection: some View {
        Section {
            SettingsRow(
                icon: "star",
                title: "レビューを書く",
                action: { openURL(AppConfig.appStoreWriteReviewURL) }
            )
            SettingsRow(
                icon: "list.bullet.clipboard",
                title: "アンケートに回答する",
                action: { showSurvey = true }
            )
        } header: {
            Text("アプリを応援")
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section {
            SettingsRow(
                icon: "lock.shield",
                title: "プライバシーポリシー",
                action: { openURL(AppConfig.privacyURL) }
            )
            SettingsRow(
                icon: "doc.text",
                title: "利用規約",
                action: { openURL(AppConfig.termsURL) }
            )
        } header: {
            Text("法的事項")
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label {
                    Text(viewModel.isClearingHistory ? "削除中…" : "履歴をすべて削除")
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .disabled(viewModel.isClearingHistory)
        } header: {
            Text("データ管理")
        } footer: {
            Text("クラウドに保存された履歴を一括で削除します。この操作は取り消せません。")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Label {
                    Text("バージョン")
                        .foregroundStyle(Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Text(viewModel.appVersionDisplay)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        } header: {
            Text("アプリ情報")
        }
    }

    // MARK: - Actions

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        #if canImport(RevenueCat)
        do {
            _ = try await purchaseService.restorePurchases()
            restoreAlertMessage = purchaseService.isPremium
                ? "Premium が復元されました。"
                : "復元可能な購入は見つかりませんでした。"
        } catch {
            restoreAlertMessage = "復元に失敗しました：\(error.localizedDescription)"
        }
        #else
        restoreAlertMessage = "この環境では復元できません。"
        #endif
        showRestoreAlert = true
    }

    /// `AppConfig.feedbackMailtoURL` を直接参照しないのは、設定タブ独自の件名
    /// （「お問い合わせ」）を付けるため。アドレスは AppConfig と同一の運用窓口。
    static var supportMailtoURL: URL {
        let subject = "ツインミラー お問い合わせ"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:appsupport0326@gmail.com?subject=\(encoded)")!
    }
}

// MARK: - Row helper

private struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label {
                    Text(title)
                        .foregroundStyle(Theme.Colors.textPrimary)
                } icon: {
                    Image(systemName: icon)
                        .foregroundStyle(Theme.Colors.accent)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary.opacity(0.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
