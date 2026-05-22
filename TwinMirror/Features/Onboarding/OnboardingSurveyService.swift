import Foundation

/// オンボーディングアンケートの状態管理と永続化を担う。
///
/// 役割：
/// - 完了済みフラグの永続化（再表示防止）
/// - 各設問の回答を UserDefaults と Firebase User Property の両方に保存
/// - 設問ごとのイベント発火（ファネル分析用）
@MainActor
@Observable
final class OnboardingSurveyService {

    static let shared = OnboardingSurveyService()

    // MARK: - Storage keys

    private static let completedKey = "twinmirror.survey.completed"
    private static let ageBracketKey = "twinmirror.survey.ageBracket"
    private static let sourceKey = "twinmirror.survey.source"
    private static let useCaseKey = "twinmirror.survey.useCase"

    // MARK: - User Property names

    private static let userPropAgeBracket = "survey_age_bracket"
    private static let userPropSource = "survey_source"
    private static let userPropUseCase = "survey_use_case"

    // MARK: - Observable state

    private(set) var isCompleted: Bool

    // MARK: - Dependencies

    private let defaults: UserDefaults
    private let analytics: AnalyticsTracking

    init(
        defaults: UserDefaults = .standard,
        analytics: AnalyticsTracking = DefaultAnalytics.shared
    ) {
        self.defaults = defaults
        self.analytics = analytics
        self.isCompleted = defaults.bool(forKey: Self.completedKey)
    }

    // MARK: - Public API

    /// 設問が回答されたタイミングで呼ぶ。
    /// - Parameters:
    ///   - step: 設問番号（1〜3）。ファネル分析用。
    ///   - key: 設問の論理キー（`"age_bracket"` / `"source"` / `"use_case"`）。
    ///   - value: Firebase に送る正規化された値（`AgeBracket.analyticsValue` 等）。
    func recordAnswer(step: Int, key: String, value: String) {
        switch key {
        case "age_bracket":
            defaults.set(value, forKey: Self.ageBracketKey)
            analytics.setUserProperty(value, forName: Self.userPropAgeBracket)
        case "source":
            defaults.set(value, forKey: Self.sourceKey)
            analytics.setUserProperty(value, forName: Self.userPropSource)
        case "use_case":
            defaults.set(value, forKey: Self.useCaseKey)
            analytics.setUserProperty(value, forName: Self.userPropUseCase)
        default:
            break
        }
        analytics.track(.onboardingSurveyQuestionAnswered(step: step, key: key, value: value))
    }

    /// 全 3 問の回答後に呼ぶ。完了フラグを立てて完了イベントを送る。
    /// 同じ完了処理を2回以上呼んでもイベントは1回だけ。
    func markCompleted(answers: OnboardingSurveyAnswers) {
        guard !isCompleted else { return }
        defaults.set(true, forKey: Self.completedKey)
        isCompleted = true

        let age = answers.age?.analyticsValue ?? "unknown"
        let source = answers.source?.analyticsValue ?? "unknown"
        let useCase = answers.useCase?.analyticsValue ?? "unknown"
        analytics.track(.onboardingSurveyCompleted(
            ageBracket: age,
            source: source,
            useCase: useCase
        ))
    }

    /// 途中スキップされたとき呼ぶ。完了フラグを立てて再表示しない。
    /// - Parameter atStep: スキップ時点の設問番号（1〜3）。
    func markSkipped(at atStep: Int) {
        guard !isCompleted else { return }
        defaults.set(true, forKey: Self.completedKey)
        isCompleted = true
        analytics.track(.onboardingSurveySkipped(atStep: atStep))
    }
}
