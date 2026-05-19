import XCTest
import UIKit
@testable import TwinMirror

private actor CallLog {
    var ids: [String] = []
    func record(_ id: String) { ids.append(id) }
    func snapshot() -> [String] { ids }
}

private struct MockImageGenerator: ImageGenerator {
    enum Behavior: Sendable {
        case success(UIImage)
        case throwing(ImageGenerationError)
    }

    let id: String
    let behavior: Behavior
    let log: CallLog

    func generate(request: GenerationRequest, prompt: String, count: Int) async throws -> [UIImage] {
        await log.record(id)
        switch behavior {
        case .success(let img):
            return Array(repeating: img, count: max(count, 1))
        case .throwing(let err):
            throw err
        }
    }
}

final class GenerationOrchestratorTests: XCTestCase {

    private func anyRequest() -> GenerationRequest {
        GenerationRequest(
            fatherImageData: Data([0x01]),
            motherImageData: Data([0x02]),
            gender: .unspecified
        )
    }

    private func anyImage() -> UIImage {
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")!
        return UIImage(data: data)!
    }

    // MARK: - premium mode (OpenAI) routing

    func test_defaultAttempts_premium_onlyOpenAIWhenKeyPresent() {
        let attempts = GenerationOrchestrator.defaultAttempts(
            geminiKey: "g", openAIKey: "sk-real", quality: .premium
        )
        XCTAssertEqual(attempts.count, 1,
                       "premium + OpenAIキーありの時はOpenAI単独")
        XCTAssertTrue(attempts.first?.generator is OpenAIImageGenerator,
                      "唯一のattemptはOpenAIでなければならない")
        XCTAssertEqual(attempts.first?.style, .photorealistic)
        XCTAssertFalse(attempts.contains(where: { $0.generator is GeminiImageGenerator }),
                       "premium + OpenAIキーありでGeminiを呼んではいけない")
    }

    func test_defaultAttempts_premium_fallsBackToGeminiWhenKeyEmpty() {
        let attempts = GenerationOrchestrator.defaultAttempts(
            geminiKey: "g", openAIKey: "", quality: .premium
        )
        XCTAssertFalse(attempts.contains(where: { $0.generator is OpenAIImageGenerator }))
        XCTAssertTrue(attempts.first?.generator is GeminiImageGenerator)
    }

    func test_defaultAttempts_premium_fallsBackToGeminiWhenPlaceholder() {
        let attempts = GenerationOrchestrator.defaultAttempts(
            geminiKey: "g",
            openAIKey: "REPLACE_WITH_YOUR_OPENAI_KEY_OR_EMPTY",
            quality: .premium
        )
        XCTAssertFalse(attempts.contains(where: { $0.generator is OpenAIImageGenerator }))
    }

    func test_defaultAttempts_premium_endsWithIllustrationFallback_whenOpenAIAbsent() {
        let attempts = GenerationOrchestrator.defaultAttempts(
            geminiKey: "g", openAIKey: "", quality: .premium
        )
        XCTAssertEqual(attempts.last?.style, .illustration,
                       "OpenAIキー未設定でpremium指定時もGeminiチェーンの最後はillustration")
    }

    // MARK: - fast mode (Gemini) routing

    func test_defaultAttempts_fast_usesGeminiOnly_evenWhenOpenAIKeyPresent() {
        let attempts = GenerationOrchestrator.defaultAttempts(
            geminiKey: "g", openAIKey: "sk-real", quality: .fast
        )
        XCTAssertFalse(attempts.contains(where: { $0.generator is OpenAIImageGenerator }),
                       "fastモードではOpenAIキーがあってもGeminiのみ使う")
        XCTAssertTrue(attempts.allSatisfy { $0.generator is GeminiImageGenerator })
        XCTAssertGreaterThanOrEqual(attempts.count, 1)
    }

    func test_defaultAttempts_fast_firstAttemptIsNanoBananaPhotoreal() {
        let attempts = GenerationOrchestrator.defaultAttempts(
            geminiKey: "g", openAIKey: "sk-real", quality: .fast
        )
        XCTAssertEqual(attempts.first?.style, .photorealistic,
                       "fastモードはまずNano Banana 2 photorealから")
    }

    // MARK: - candidate count per quality

    func test_quality_premium_requestsSingleCandidate() {
        XCTAssertEqual(GenerationQuality.premium.candidateCount, 1,
                       "プレミアムモードは高画質1枚のみ生成（時間とコストを抑える）")
    }

    func test_quality_fast_requestsMultipleCandidates() {
        XCTAssertEqual(GenerationQuality.fast.candidateCount, 3,
                       "高速モードは候補を複数生成してカルーセル表示")
    }

    func test_generate_firstSuccess_doesNotCallSubsequent() async throws {
        let log = CallLog()
        let a = MockImageGenerator(id: "A", behavior: .success(anyImage()), log: log)
        let b = MockImageGenerator(id: "B", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: a, style: .photorealistic),
            .init(generator: b, style: .photorealistic)
        ])

        let result = try await orchestrator.generate(request: anyRequest(), candidateCount: 1)
        XCTAssertEqual(result.usedStyle, .photorealistic)
        let ids = await log.snapshot()
        XCTAssertEqual(ids, ["A"], "B must not be called after A succeeds")
    }

    func test_generate_safetyBlock_fallsThroughToNext() async throws {
        let log = CallLog()
        let blocked = MockImageGenerator(id: "blocked", behavior: .throwing(.safetyBlocked(reason: "X")), log: log)
        let ok = MockImageGenerator(id: "ok", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: blocked, style: .photorealistic),
            .init(generator: ok, style: .photorealistic)
        ])

        _ = try await orchestrator.generate(request: anyRequest(), candidateCount: 1)
        let ids = await log.snapshot()
        XCTAssertEqual(ids, ["blocked", "ok"])
    }

    func test_generate_missingKey_fallsThroughToNext() async throws {
        let log = CallLog()
        let noKey = MockImageGenerator(id: "noKey", behavior: .throwing(.missingAPIKey), log: log)
        let ok = MockImageGenerator(id: "ok", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: noKey, style: .photorealistic),
            .init(generator: ok, style: .photorealistic)
        ])

        _ = try await orchestrator.generate(request: anyRequest(), candidateCount: 1)
        let ids = await log.snapshot()
        XCTAssertEqual(ids, ["noKey", "ok"])
    }

    func test_generate_allFail_throwsLastError() async {
        let log = CallLog()
        let a = MockImageGenerator(id: "A", behavior: .throwing(.safetyBlocked(reason: "1")), log: log)
        let b = MockImageGenerator(id: "B", behavior: .throwing(.noImageReturned), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: a, style: .photorealistic),
            .init(generator: b, style: .photorealistic)
        ])

        do {
            _ = try await orchestrator.generate(request: anyRequest(), candidateCount: 1)
            XCTFail("Should have thrown")
        } catch {
            if case ImageGenerationError.noImageReturned = error {
                // expected — last error propagates
            } else {
                XCTFail("Expected noImageReturned, got \(error)")
            }
        }
        let ids = await log.snapshot()
        XCTAssertEqual(ids, ["A", "B"])
    }

    func test_generate_nonTransientError_stopsImmediately() async {
        let log = CallLog()
        let bad = MockImageGenerator(id: "bad", behavior: .throwing(.decodingFailed), log: log)
        let ok = MockImageGenerator(id: "ok", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: bad, style: .photorealistic),
            .init(generator: ok, style: .photorealistic)
        ])

        do {
            _ = try await orchestrator.generate(request: anyRequest(), candidateCount: 1)
            XCTFail("Should have thrown")
        } catch {
            if case ImageGenerationError.decodingFailed = error {
                // expected
            } else {
                XCTFail("Expected decodingFailed, got \(error)")
            }
        }
        let ids = await log.snapshot()
        XCTAssertEqual(ids, ["bad"], "ok must NOT be called for non-transient errors")
    }
}
