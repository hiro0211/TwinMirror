import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// アプリ全体で扱う計測イベント定義。
///
/// Firebase Analytics 命名規約に従い、イベント名・パラメータ名は `snake_case`。
/// パラメータ値は `String` / `Int` / `Double` のみ（Firebase は Bool 非対応のため
/// `Int` 0/1 にマップする）。
enum AnalyticsEvent: Sendable {
    case homeViewed
    case composeOpened
    case composeImageSet(slot: String, faceDetected: Bool)
    case composeGenerateTapped(gender: String, age: Int, mode: String)
    case generationStarted(mode: String)
    case generationSucceeded(mode: String, elapsedMs: Int, imageCount: Int)
    case generationFailed(mode: String, errorKind: String)
    case resultRegenerated(newGender: String)
    case resultSaved(index: Int)
    case resultSaveFailed(errorKind: String)
    case usageLimitHit(mode: String)
    case paywallShown(source: String)
    case purchaseCompleted(packageID: String)
    case restoreCompleted(wasPremium: Bool)
    case reviewPromptShown
    case reviewPromptAnswered(satisfied: Bool)
    case reviewPromptCtaTapped(action: String)
    case onboardingSurveyShown
    case onboardingSurveyQuestionAnswered(step: Int, key: String, value: String)
    case onboardingSurveyCompleted(ageBracket: String, source: String, useCase: String)
    case onboardingSurveySkipped(atStep: Int)

    var name: String {
        switch self {
        case .homeViewed:             return "home_viewed"
        case .composeOpened:          return "compose_opened"
        case .composeImageSet:        return "compose_image_set"
        case .composeGenerateTapped:  return "compose_generate_tapped"
        case .generationStarted:      return "generation_started"
        case .generationSucceeded:    return "generation_succeeded"
        case .generationFailed:       return "generation_failed"
        case .resultRegenerated:      return "result_regenerated"
        case .resultSaved:            return "result_saved"
        case .resultSaveFailed:       return "result_save_failed"
        case .usageLimitHit:          return "usage_limit_hit"
        case .paywallShown:           return "paywall_shown"
        case .purchaseCompleted:      return "purchase_completed"
        case .restoreCompleted:       return "restore_completed"
        case .reviewPromptShown:      return "review_prompt_shown"
        case .reviewPromptAnswered:   return "review_prompt_answered"
        case .reviewPromptCtaTapped:  return "review_prompt_cta_tapped"
        case .onboardingSurveyShown:           return "onboarding_survey_shown"
        case .onboardingSurveyQuestionAnswered: return "onboarding_survey_question_answered"
        case .onboardingSurveyCompleted:       return "onboarding_survey_completed"
        case .onboardingSurveySkipped:         return "onboarding_survey_skipped"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .homeViewed, .composeOpened, .reviewPromptShown, .onboardingSurveyShown:
            return [:]
        case .composeImageSet(let slot, let faceDetected):
            return ["slot": slot, "face_detected": faceDetected ? 1 : 0]
        case .composeGenerateTapped(let gender, let age, let mode):
            return ["gender": gender, "age": age, "mode": mode]
        case .generationStarted(let mode):
            return ["mode": mode]
        case .generationSucceeded(let mode, let elapsedMs, let imageCount):
            return ["mode": mode, "elapsed_ms": elapsedMs, "image_count": imageCount]
        case .generationFailed(let mode, let errorKind):
            return ["mode": mode, "error_kind": errorKind]
        case .resultRegenerated(let newGender):
            return ["new_gender": newGender]
        case .resultSaved(let index):
            return ["index": index]
        case .resultSaveFailed(let errorKind):
            return ["error_kind": errorKind]
        case .usageLimitHit(let mode):
            return ["mode": mode]
        case .paywallShown(let source):
            return ["source": source]
        case .purchaseCompleted(let packageID):
            return ["package_id": packageID]
        case .restoreCompleted(let wasPremium):
            return ["was_premium": wasPremium ? 1 : 0]
        case .reviewPromptAnswered(let satisfied):
            return ["satisfied": satisfied ? 1 : 0]
        case .reviewPromptCtaTapped(let action):
            return ["action": action]
        case .onboardingSurveyQuestionAnswered(let step, let key, let value):
            return ["step": step, "key": key, "value": value]
        case .onboardingSurveyCompleted(let ageBracket, let source, let useCase):
            return ["age_bracket": ageBracket, "source": source, "use_case": useCase]
        case .onboardingSurveySkipped(let atStep):
            return ["at_step": atStep]
        }
    }
}

protocol AnalyticsTracking: Sendable {
    func track(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String?, forName name: String)
}

/// テスト・プレビュー用にイベントを破棄する実装。
struct NoopAnalyticsService: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {}
    func setUserProperty(_ value: String?, forName name: String) {}
}

/// Firebase Analytics に転送する本番実装。
///
/// `FirebaseAnalytics` モジュールが利用可能な場合のみ実際に送信し、
/// それ以外（例えばユニットテストや Firebase 未統合の段階）は no-op になる。
struct FirebaseAnalyticsService: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.name, parameters: event.parameters)
        #endif
    }

    func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }
}

/// アプリ全体で共有する既定の Analytics 実装。
/// テスト時はビューモデルの init に SpyAnalyticsTracking を注入して差し替える。
enum DefaultAnalytics {
    static let shared: AnalyticsTracking = FirebaseAnalyticsService()
}
