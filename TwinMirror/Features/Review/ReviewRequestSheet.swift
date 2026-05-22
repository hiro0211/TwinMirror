import SwiftUI

/// アプリレビュー依頼モーダル。
///
/// 2 段階の Satisfaction Gate パターン：
/// 1. 満足度確認：「いかがですか？」 → ポジティブ/ネガティブで分岐
/// 2a. ポジティブ → App Store のレビュー記入ページへ誘導
/// 2b. ネガティブ → メールでのフィードバック窓口へ誘導
///
/// Apple App Store Review Guideline に抵触しないよう、native の `requestReview` は
/// 使わず、App Store の write-review ディープリンクに直接遷移する設計。
struct ReviewRequestSheet: View {

    enum Step: Equatable {
        case satisfaction
        case askReview
        case askFeedback
    }

    let service: ReviewRequestService
    private let analytics: AnalyticsTracking

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var step: Step = .satisfaction

    init(
        service: ReviewRequestService,
        analytics: AnalyticsTracking = DefaultAnalytics.shared
    ) {
        self.service = service
        self.analytics = analytics
    }

    var body: some View {
        ZStack {
            Theme.Gradients.background.ignoresSafeArea()

            switch step {
            case .satisfaction: satisfactionBody
            case .askReview:    askReviewBody
            case .askFeedback:  askFeedbackBody
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.Colors.cream)
        .onAppear {
            analytics.track(.reviewPromptShown)
            service.markPresented()
        }
    }

    // MARK: - Step 1: Satisfaction

    private var satisfactionBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            header(
                icon: "sparkles",
                iconColor: Theme.Colors.primaryDeep,
                title: "ツインミラーはいかがですか？",
                subtitle: "率直なご感想をお聞かせください"
            )

            Spacer()

            VStack(spacing: Theme.Spacing.s) {
                GlassButton(isProminent: true, action: {
                    analytics.track(.reviewPromptAnswered(satisfied: true))
                    step = .askReview
                }) {
                    Text("気に入っている 😊")
                }
                GlassButton(tint: Theme.Colors.accent, action: {
                    analytics.track(.reviewPromptAnswered(satisfied: false))
                    step = .askFeedback
                }) {
                    Text("もう少し")
                }
            }
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    // MARK: - Step 2a: Ask for App Store review

    private var askReviewBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            header(
                icon: "heart.fill",
                iconColor: Theme.Colors.primary,
                title: "ありがとうございます！",
                subtitle: nil
            )

            Text("もしよろしければ、App Store で星評価をいただけませんか。\nあなたの一言が次のアップデートの励みになります。")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(4)

            Spacer()

            VStack(spacing: Theme.Spacing.s) {
                GlassButton(isProminent: true, action: {
                    analytics.track(.reviewPromptCtaTapped(action: "open_app_store"))
                    openURL(AppConfig.appStoreWriteReviewURL)
                    dismiss()
                }) {
                    Text("App Store でレビューを書く")
                }
                Button("あとで") {
                    analytics.track(.reviewPromptCtaTapped(action: "dismiss"))
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.7))
            }
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    // MARK: - Step 2b: Ask for feedback via email

    private var askFeedbackBody: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            header(
                icon: "bubble.left.and.bubble.right.fill",
                iconColor: Theme.Colors.accent,
                title: "ご意見をお聞かせください",
                subtitle: nil
            )

            Text("気になった点や改善してほしいところを教えていただけると、これからの開発の参考にさせていただきます。")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(4)

            Spacer()

            VStack(spacing: Theme.Spacing.s) {
                GlassButton(tint: Theme.Colors.accent, isProminent: true, action: {
                    analytics.track(.reviewPromptCtaTapped(action: "open_feedback"))
                    openURL(AppConfig.feedbackMailtoURL)
                    dismiss()
                }) {
                    Text("ご意見を送る")
                }
                Button("閉じる") {
                    analytics.track(.reviewPromptCtaTapped(action: "dismiss"))
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.7))
            }
            .padding(.bottom, Theme.Spacing.l)
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    // MARK: - Header helper

    @ViewBuilder
    private func header(icon: String, iconColor: Color, title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.top, Theme.Spacing.l)
    }
}

#Preview {
    ZStack { Theme.Gradients.background.ignoresSafeArea() }
        .sheet(isPresented: .constant(true)) {
            ReviewRequestSheet(
                service: ReviewRequestService.shared,
                analytics: NoopAnalyticsService()
            )
        }
}
