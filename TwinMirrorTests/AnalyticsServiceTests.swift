import XCTest
import UIKit
@testable import TwinMirror

final class SpyAnalyticsTracking: AnalyticsTracking, @unchecked Sendable {
    var trackedEvents: [AnalyticsEvent] = []
    var userProperties: [String: String?] = [:]

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        userProperties[name] = value
    }
}

final class AnalyticsEventNameTests: XCTestCase {
    func test_eventNames_useSnakeCase() {
        XCTAssertEqual(AnalyticsEvent.homeViewed.name, "home_viewed")
        XCTAssertEqual(AnalyticsEvent.composeOpened.name, "compose_opened")
        XCTAssertEqual(
            AnalyticsEvent.composeImageSet(slot: "father", faceDetected: true).name,
            "compose_image_set"
        )
        XCTAssertEqual(
            AnalyticsEvent.composeGenerateTapped(gender: "female", age: 5, mode: "fast").name,
            "compose_generate_tapped"
        )
        XCTAssertEqual(AnalyticsEvent.generationStarted(mode: "fast").name, "generation_started")
        XCTAssertEqual(
            AnalyticsEvent.generationSucceeded(mode: "fast", elapsedMs: 100, imageCount: 1).name,
            "generation_succeeded"
        )
        XCTAssertEqual(
            AnalyticsEvent.generationFailed(mode: "fast", errorKind: "any").name,
            "generation_failed"
        )
        XCTAssertEqual(
            AnalyticsEvent.resultRegenerated(newGender: "male").name,
            "result_regenerated"
        )
        XCTAssertEqual(AnalyticsEvent.resultSaved(index: 0).name, "result_saved")
        XCTAssertEqual(
            AnalyticsEvent.resultSaveFailed(errorKind: "denied").name,
            "result_save_failed"
        )
        XCTAssertEqual(AnalyticsEvent.usageLimitHit(mode: "fast").name, "usage_limit_hit")
        XCTAssertEqual(AnalyticsEvent.paywallShown(source: "limit_hit").name, "paywall_shown")
        XCTAssertEqual(AnalyticsEvent.purchaseCompleted(packageID: "monthly").name, "purchase_completed")
        XCTAssertEqual(AnalyticsEvent.restoreCompleted(wasPremium: true).name, "restore_completed")
        XCTAssertEqual(AnalyticsEvent.reviewPromptShown.name, "review_prompt_shown")
        XCTAssertEqual(AnalyticsEvent.reviewPromptAnswered(satisfied: true).name, "review_prompt_answered")
        XCTAssertEqual(AnalyticsEvent.reviewPromptCtaTapped(action: "open_app_store").name, "review_prompt_cta_tapped")
        XCTAssertEqual(AnalyticsEvent.onboardingSurveyShown.name, "onboarding_survey_shown")
        XCTAssertEqual(
            AnalyticsEvent.onboardingSurveyQuestionAnswered(step: 1, key: "age_bracket", value: "under_25").name,
            "onboarding_survey_question_answered"
        )
        XCTAssertEqual(
            AnalyticsEvent.onboardingSurveyCompleted(ageBracket: "25_34", source: "social", useCase: "curiosity").name,
            "onboarding_survey_completed"
        )
        XCTAssertEqual(AnalyticsEvent.onboardingSurveySkipped(atStep: 2).name, "onboarding_survey_skipped")
    }

    func test_onboardingSurveyQuestionAnswered_parameters() {
        let event = AnalyticsEvent.onboardingSurveyQuestionAnswered(step: 2, key: "source", value: "word_of_mouth")
        XCTAssertEqual(event.parameters["step"] as? Int, 2)
        XCTAssertEqual(event.parameters["key"] as? String, "source")
        XCTAssertEqual(event.parameters["value"] as? String, "word_of_mouth")
    }

    func test_onboardingSurveyCompleted_parameters() {
        let event = AnalyticsEvent.onboardingSurveyCompleted(
            ageBracket: "25_34",
            source: "social",
            useCase: "imagine_with_partner"
        )
        XCTAssertEqual(event.parameters["age_bracket"] as? String, "25_34")
        XCTAssertEqual(event.parameters["source"] as? String, "social")
        XCTAssertEqual(event.parameters["use_case"] as? String, "imagine_with_partner")
    }

    func test_onboardingSurveySkipped_parameters() {
        XCTAssertEqual(AnalyticsEvent.onboardingSurveySkipped(atStep: 3).parameters["at_step"] as? Int, 3)
    }

    func test_reviewPromptAnswered_mapsBoolToInt() {
        XCTAssertEqual(AnalyticsEvent.reviewPromptAnswered(satisfied: true).parameters["satisfied"] as? Int, 1)
        XCTAssertEqual(AnalyticsEvent.reviewPromptAnswered(satisfied: false).parameters["satisfied"] as? Int, 0)
    }

    func test_reviewPromptCtaTapped_parameters() {
        let event = AnalyticsEvent.reviewPromptCtaTapped(action: "open_feedback")
        XCTAssertEqual(event.parameters["action"] as? String, "open_feedback")
    }

    func test_paywallShown_parameters() {
        let event = AnalyticsEvent.paywallShown(source: "pro_button")
        XCTAssertEqual(event.parameters["source"] as? String, "pro_button")
    }

    func test_restoreCompleted_mapsBoolToInt() {
        XCTAssertEqual(AnalyticsEvent.restoreCompleted(wasPremium: true).parameters["was_premium"] as? Int, 1)
        XCTAssertEqual(AnalyticsEvent.restoreCompleted(wasPremium: false).parameters["was_premium"] as? Int, 0)
    }

    func test_composeImageSet_parametersUseSnakeCase() {
        let event = AnalyticsEvent.composeImageSet(slot: "mother", faceDetected: false)
        XCTAssertEqual(event.parameters["slot"] as? String, "mother")
        // Firebase Analytics rejects Bool; map to Int 0/1.
        XCTAssertEqual(event.parameters["face_detected"] as? Int, 0)
    }

    func test_composeGenerateTapped_parameters() {
        let event = AnalyticsEvent.composeGenerateTapped(gender: "male", age: 7, mode: "premium")
        XCTAssertEqual(event.parameters["gender"] as? String, "male")
        XCTAssertEqual(event.parameters["age"] as? Int, 7)
        XCTAssertEqual(event.parameters["mode"] as? String, "premium")
    }

    func test_generationSucceeded_parameters() {
        let event = AnalyticsEvent.generationSucceeded(mode: "fast", elapsedMs: 1234, imageCount: 1)
        XCTAssertEqual(event.parameters["mode"] as? String, "fast")
        XCTAssertEqual(event.parameters["elapsed_ms"] as? Int, 1234)
        XCTAssertEqual(event.parameters["image_count"] as? Int, 1)
    }
}

@MainActor
final class ComposeViewModelAnalyticsTests: XCTestCase {
    func test_setImage_success_emitsComposeImageSetWithFaceDetected() async {
        let spy = SpyAnalyticsTracking()
        let vm = ComposeViewModel(analytics: spy)
        let image = makePixelImage()

        await vm.setImage(image, for: .father)

        // FaceDetectionService will fail on a 1x1 image (no face). We still
        // expect the event to be tracked with faceDetected=false so the funnel
        // can capture even the "tried to set image" event.
        guard let last = spy.trackedEvents.last,
              case .composeImageSet(let slot, _) = last else {
            return XCTFail("composeImageSet was not tracked, got \(spy.trackedEvents)")
        }
        XCTAssertEqual(slot, "father")
    }

    private func makePixelImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}

@MainActor
final class ResultViewModelAnalyticsTests: XCTestCase {

    private final class StubSaver: PhotoSaving, @unchecked Sendable {
        var shouldThrow: Error?
        func save(_ image: UIImage) async throws {
            if let shouldThrow { throw shouldThrow }
        }
    }

    private func anyRequest() -> GenerationRequest {
        GenerationRequest(
            fatherImageData: Data([0x01]),
            motherImageData: Data([0x02]),
            gender: .unspecified,
            age: ChildAge(years: 5),
            mode: .fast
        )
    }

    private func pixel() -> UIImage {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return r.image { _ in }
    }

    func test_saveCurrent_success_emitsResultSaved() async {
        let spy = SpyAnalyticsTracking()
        let saver = StubSaver()
        let vm = ResultViewModel(
            initialRequest: anyRequest(),
            fatherImage: pixel(),
            motherImage: pixel(),
            saveService: saver,
            analytics: spy
        )
        vm.phase = .done(GenerationResult(images: [pixel(), pixel()], bestIndex: 0, usedStyle: .photorealistic))

        await vm.saveCurrent(at: 1)

        guard let last = spy.trackedEvents.last,
              case .resultSaved(let index) = last else {
            return XCTFail("resultSaved not tracked. got \(spy.trackedEvents)")
        }
        XCTAssertEqual(index, 1)
    }

    func test_saveCurrent_failure_emitsResultSaveFailed() async {
        let spy = SpyAnalyticsTracking()
        let saver = StubSaver()
        saver.shouldThrow = PhotoSaveError.unauthorized
        let vm = ResultViewModel(
            initialRequest: anyRequest(),
            fatherImage: pixel(),
            motherImage: pixel(),
            saveService: saver,
            analytics: spy
        )
        vm.phase = .done(GenerationResult(images: [pixel()], bestIndex: 0, usedStyle: .photorealistic))

        await vm.saveCurrent(at: 0)

        guard let last = spy.trackedEvents.last,
              case .resultSaveFailed = last else {
            return XCTFail("resultSaveFailed not tracked. got \(spy.trackedEvents)")
        }
    }
}
