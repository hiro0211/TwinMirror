import SwiftUI

/// 初回起動時に表示される 3 問のオンボーディングアンケート画面。
/// `.fullScreenCover` で表示し、完了またはスキップで dismiss する。
struct OnboardingSurveyView: View {

    let service: OnboardingSurveyService
    private let analytics: AnalyticsTracking

    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1
    @State private var answers = OnboardingSurveyAnswers()
    @State private var showThanks: Bool = false

    init(
        service: OnboardingSurveyService,
        analytics: AnalyticsTracking = DefaultAnalytics.shared
    ) {
        self.service = service
        self.analytics = analytics
    }

    var body: some View {
        ZStack {
            Theme.Gradients.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                topBar
                progressIndicator
                questionTitle
                ScrollView {
                    VStack(spacing: Theme.Spacing.s) {
                        currentOptions
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, Theme.Spacing.m)

            if showThanks {
                thanksOverlay
                    .transition(.opacity)
            }
        }
        .onAppear {
            analytics.track(.onboardingSurveyShown)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .animation(.easeInOut(duration: 0.2), value: showThanks)
    }

    // MARK: - Top bar (戻る / スキップ)

    private var topBar: some View {
        HStack {
            if step > 1 && !showThanks {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("ひとつ前の質問に戻る")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            if !showThanks {
                Button("スキップ") {
                    service.markSkipped(at: step)
                    dismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.trailing, Theme.Spacing.s)
            }
        }
        .padding(.horizontal, Theme.Spacing.s)
    }

    // MARK: - Progress

    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(1...3, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.Colors.primaryDeep : Theme.Colors.primary.opacity(0.25))
                        .frame(height: 6)
                }
            }
            Text("\(step) / 3")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.l)
    }

    // MARK: - Question title

    @ViewBuilder
    private var questionTitle: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(titleForStep(step))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitleForStep(step))
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
    }

    private func titleForStep(_ step: Int) -> String {
        switch step {
        case 1: return "あなたの年齢を教えてください"
        case 2: return "ツインミラーをどこで知りましたか？"
        case 3: return "主にどのように使いたいですか？"
        default: return ""
        }
    }

    private func subtitleForStep(_ step: Int) -> String {
        switch step {
        case 1: return "サービス改善のために伺います（任意）"
        case 2: return "あなたに合った情報をお届けするために"
        case 3: return "これからの機能づくりの参考にします"
        default: return ""
        }
    }

    // MARK: - Options per step

    @ViewBuilder
    private var currentOptions: some View {
        switch step {
        case 1: ageOptions
        case 2: sourceOptions
        case 3: useCaseOptions
        default: EmptyView()
        }
    }

    private var ageOptions: some View {
        ForEach(AgeBracket.allCases, id: \.self) { option in
            SurveyOptionCard(
                title: option.displayLabel,
                iconName: nil,
                isSelected: answers.age == option,
                action: {
                    answers.age = option
                    service.recordAnswer(step: 1, key: "age_bracket", value: option.analyticsValue)
                    advance()
                }
            )
        }
    }

    private var sourceOptions: some View {
        ForEach(AcquisitionSource.allCases, id: \.self) { option in
            SurveyOptionCard(
                title: option.displayLabel,
                iconName: option.iconName,
                isSelected: answers.source == option,
                action: {
                    answers.source = option
                    service.recordAnswer(step: 2, key: "source", value: option.analyticsValue)
                    advance()
                }
            )
        }
    }

    private var useCaseOptions: some View {
        ForEach(UseCase.allCases, id: \.self) { option in
            SurveyOptionCard(
                title: option.displayLabel,
                iconName: option.iconName,
                isSelected: answers.useCase == option,
                action: {
                    answers.useCase = option
                    service.recordAnswer(step: 3, key: "use_case", value: option.analyticsValue)
                    advance()
                }
            )
        }
    }

    // MARK: - Step navigation

    private func advance() {
        if step < 3 {
            step += 1
        } else {
            finish()
        }
    }

    private func goBack() {
        if step > 1 { step -= 1 }
    }

    private func finish() {
        service.markCompleted(answers: answers)
        showThanks = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            dismiss()
        }
    }

    // MARK: - Thanks overlay

    private var thanksOverlay: some View {
        ZStack {
            Theme.Gradients.background.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primaryDeep)
                Text("ありがとうございます！")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("いただいた回答はサービス改善に活用させていただきます。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.l)
            }
        }
    }
}

#Preview {
    OnboardingSurveyView(
        service: OnboardingSurveyService(),
        analytics: NoopAnalyticsService()
    )
}
