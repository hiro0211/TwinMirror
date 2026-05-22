import XCTest
@testable import TwinMirror

@MainActor
final class OnboardingSurveyServiceTests: XCTestCase {

    private let suiteName = "twinmirror.survey.tests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeService(
        analytics: AnalyticsTracking = SpyAnalyticsTracking()
    ) -> OnboardingSurveyService {
        OnboardingSurveyService(defaults: defaults, analytics: analytics)
    }

    // MARK: - Initial state

    func test_initialState_isNotCompleted() {
        let svc = makeService()
        XCTAssertFalse(svc.isCompleted)
    }

    func test_initialState_readsCompletedFlagFromDefaults() {
        defaults.set(true, forKey: "twinmirror.survey.completed")
        let svc = makeService()
        XCTAssertTrue(svc.isCompleted)
    }

    // MARK: - Recording answers

    func test_recordAnswer_persistsValueAndTracksEvent() {
        let spy = SpyAnalyticsTracking()
        let svc = makeService(analytics: spy)

        svc.recordAnswer(step: 1, key: "age_bracket", value: "25_34")

        XCTAssertEqual(defaults.string(forKey: "twinmirror.survey.ageBracket"), "25_34")
        guard let last = spy.trackedEvents.last,
              case .onboardingSurveyQuestionAnswered(let step, let key, let value) = last else {
            return XCTFail("question_answered not tracked. got \(spy.trackedEvents)")
        }
        XCTAssertEqual(step, 1)
        XCTAssertEqual(key, "age_bracket")
        XCTAssertEqual(value, "25_34")
    }

    func test_recordAnswer_setsUserProperty() {
        let spy = SpyAnalyticsTracking()
        let svc = makeService(analytics: spy)

        svc.recordAnswer(step: 2, key: "source", value: "social")

        XCTAssertEqual(spy.userProperties["survey_source"], "social")
    }

    func test_recordAnswer_writesToCorrectDefaultsKeyPerStep() {
        let svc = makeService()
        svc.recordAnswer(step: 1, key: "age_bracket", value: "under_25")
        svc.recordAnswer(step: 2, key: "source", value: "app_store")
        svc.recordAnswer(step: 3, key: "use_case", value: "curiosity")

        XCTAssertEqual(defaults.string(forKey: "twinmirror.survey.ageBracket"), "under_25")
        XCTAssertEqual(defaults.string(forKey: "twinmirror.survey.source"), "app_store")
        XCTAssertEqual(defaults.string(forKey: "twinmirror.survey.useCase"), "curiosity")
    }

    // MARK: - Completion

    func test_markCompleted_setsCompletedAndEmitsEvent() {
        let spy = SpyAnalyticsTracking()
        let svc = makeService(analytics: spy)

        let answers = OnboardingSurveyAnswers(
            age: .age25to34,
            source: .social,
            useCase: .imagineWithPartner
        )
        svc.markCompleted(answers: answers)

        XCTAssertTrue(svc.isCompleted)
        XCTAssertTrue(defaults.bool(forKey: "twinmirror.survey.completed"))

        guard let last = spy.trackedEvents.last,
              case .onboardingSurveyCompleted(let age, let source, let useCase) = last else {
            return XCTFail("completed event not tracked")
        }
        XCTAssertEqual(age, "25_34")
        XCTAssertEqual(source, "social")
        XCTAssertEqual(useCase, "imagine_with_partner")
    }

    func test_markCompleted_isIdempotent() {
        let spy = SpyAnalyticsTracking()
        let svc = makeService(analytics: spy)

        let answers = OnboardingSurveyAnswers(age: .under25, source: .ad, useCase: .curiosity)
        svc.markCompleted(answers: answers)
        let countAfterFirst = spy.trackedEvents.count
        svc.markCompleted(answers: answers)

        // 2回目は副作用なし（completed イベントが2回飛ばない）
        XCTAssertEqual(spy.trackedEvents.count, countAfterFirst)
        XCTAssertTrue(svc.isCompleted)
    }

    // MARK: - Skip

    func test_markSkipped_setsCompletedAndEmitsEvent() {
        let spy = SpyAnalyticsTracking()
        let svc = makeService(analytics: spy)

        svc.markSkipped(at: 2)

        XCTAssertTrue(svc.isCompleted, "スキップ後も再表示はしない")
        XCTAssertTrue(defaults.bool(forKey: "twinmirror.survey.completed"))
        guard let last = spy.trackedEvents.last,
              case .onboardingSurveySkipped(let atStep) = last else {
            return XCTFail("skipped event not tracked")
        }
        XCTAssertEqual(atStep, 2)
    }
}
