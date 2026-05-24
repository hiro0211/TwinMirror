import XCTest
import UIKit
@testable import TwinMirror

private actor CallLog {
    var entries: [(id: String, prompt: String)] = []
    func record(_ id: String, prompt: String) { entries.append((id, prompt)) }
    func snapshotIDs() -> [String] { entries.map(\.id) }
    func snapshotPrompts() -> [String] { entries.map(\.prompt) }
}

private struct MockImageGenerator: ImageGenerator {
    enum Behavior: Sendable {
        case success(UIImage)
        case throwing(ImageGenerationError)
    }

    let id: String
    let behavior: Behavior
    let log: CallLog

    func generate(request: GenerationRequest, prompt: String) async throws -> UIImage {
        await log.record(id, prompt: prompt)
        switch behavior {
        case .success(let img): return img
        case .throwing(let err): throw err
        }
    }
}

/// `MockImageGenerator` だと behavior が固定で「最初のリクエストは失敗→2回目以降は成功」みたいな
/// 並列パイプライン用テストを書けないので、`ratio` 単位で挙動を切り替えられる派生を用意する。
private struct PerRatioMockGenerator: ImageGenerator {
    enum Behavior: Sendable {
        case success(UIImage)
        case throwing(ImageGenerationError)
    }

    let id: String
    /// Key: BlendRatio.rawValue ("balanced" / "fatherLeaning" / "motherLeaning")
    let behaviorByPromptKeyword: [String: Behavior]
    let log: CallLog

    func generate(request: GenerationRequest, prompt: String) async throws -> UIImage {
        await log.record(id, prompt: prompt)
        for (keyword, behavior) in behaviorByPromptKeyword {
            if prompt.contains(keyword) {
                switch behavior {
                case .success(let img): return img
                case .throwing(let err): throw err
                }
            }
        }
        throw ImageGenerationError.allFallbacksExhausted
    }
}

final class GenerationOrchestratorTests: XCTestCase {

    private func anyRequest(mode: GenerationMode = .fast) -> GenerationRequest {
        GenerationRequest(
            fatherImageData: Data([0x01]),
            motherImageData: Data([0x02]),
            gender: .unspecified,
            mode: mode
        )
    }

    private func anyImage() -> UIImage {
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")!
        return UIImage(data: data)!
    }

    // MARK: - default chain composition (Gemini only)

    func test_defaultAttempts_usesGeminiOnly() {
        let attempts = GenerationOrchestrator.defaultAttempts(workerURL: URL(string: "https://worker.example.com")!, authToken: "tok")
        XCTAssertTrue(attempts.allSatisfy { $0.generator is GeminiImageGenerator },
                      "本番チェーンはGeminiのみで構成される（OpenAIは削除済み）")
        XCTAssertGreaterThanOrEqual(attempts.count, 1)
    }

    func test_defaultAttempts_firstIsProImagePhotoreal() {
        let attempts = GenerationOrchestrator.defaultAttempts(workerURL: URL(string: "https://worker.example.com")!, authToken: "tok")
        XCTAssertEqual(attempts.first?.style, .photorealistic,
                       "1番目は gemini-3-pro-image-preview の photorealistic (Flash より速いため優先)")
    }

    func test_defaultAttempts_lastIsIllustration() {
        let attempts = GenerationOrchestrator.defaultAttempts(workerURL: URL(string: "https://worker.example.com")!, authToken: "tok")
        XCTAssertEqual(attempts.last?.style, .illustration,
                       "最後の砦は illustration スタイル")
    }

    // MARK: - fast mode (single image)

    func test_generate_fast_firstSuccess_doesNotCallSubsequent() async throws {
        let log = CallLog()
        let a = MockImageGenerator(id: "A", behavior: .success(anyImage()), log: log)
        let b = MockImageGenerator(id: "B", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: a, style: .photorealistic),
            .init(generator: b, style: .photorealistic)
        ])

        let result = try await orchestrator.generate(request: anyRequest())
        XCTAssertEqual(result.usedStyle, .photorealistic)
        XCTAssertEqual(result.images.count, 1, "fast モードは1枚")
        XCTAssertEqual(result.ratios, [.balanced])
        let ids = await log.snapshotIDs()
        XCTAssertEqual(ids, ["A"], "B must not be called after A succeeds")
    }

    func test_generate_fast_safetyBlock_fallsThroughToNext() async throws {
        let log = CallLog()
        let blocked = MockImageGenerator(id: "blocked", behavior: .throwing(.safetyBlocked(reason: "X")), log: log)
        let ok = MockImageGenerator(id: "ok", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: blocked, style: .photorealistic),
            .init(generator: ok, style: .photorealistic)
        ])

        _ = try await orchestrator.generate(request: anyRequest())
        let ids = await log.snapshotIDs()
        XCTAssertEqual(ids, ["blocked", "ok"])
    }

    func test_generate_fast_missingKey_fallsThroughToNext() async throws {
        let log = CallLog()
        let noKey = MockImageGenerator(id: "noKey", behavior: .throwing(.missingAPIKey), log: log)
        let ok = MockImageGenerator(id: "ok", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: noKey, style: .photorealistic),
            .init(generator: ok, style: .photorealistic)
        ])

        _ = try await orchestrator.generate(request: anyRequest())
        let ids = await log.snapshotIDs()
        XCTAssertEqual(ids, ["noKey", "ok"])
    }

    func test_generate_fast_allFail_throwsLastError() async {
        let log = CallLog()
        let a = MockImageGenerator(id: "A", behavior: .throwing(.safetyBlocked(reason: "1")), log: log)
        let b = MockImageGenerator(id: "B", behavior: .throwing(.noImageReturned), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: a, style: .photorealistic),
            .init(generator: b, style: .photorealistic)
        ])

        do {
            _ = try await orchestrator.generate(request: anyRequest())
            XCTFail("Should have thrown")
        } catch {
            if case ImageGenerationError.noImageReturned = error {
                // expected — last error propagates
            } else {
                XCTFail("Expected noImageReturned, got \(error)")
            }
        }
        let ids = await log.snapshotIDs()
        XCTAssertEqual(ids, ["A", "B"])
    }

    func test_generate_fast_nonTransientError_stopsImmediately() async {
        let log = CallLog()
        let bad = MockImageGenerator(id: "bad", behavior: .throwing(.decodingFailed), log: log)
        let ok = MockImageGenerator(id: "ok", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: bad, style: .photorealistic),
            .init(generator: ok, style: .photorealistic)
        ])

        do {
            _ = try await orchestrator.generate(request: anyRequest())
            XCTFail("Should have thrown")
        } catch {
            if case ImageGenerationError.decodingFailed = error {
                // expected
            } else {
                XCTFail("Expected decodingFailed, got \(error)")
            }
        }
        let ids = await log.snapshotIDs()
        XCTAssertEqual(ids, ["bad"], "ok must NOT be called for non-transient errors")
    }

    // MARK: - premium mode (3 images, parallel)

    func test_generate_premium_returnsThreeImagesWithAllRatios() async throws {
        let log = CallLog()
        let gen = MockImageGenerator(id: "G", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: gen, style: .photorealistic)
        ])

        let result = try await orchestrator.generate(request: anyRequest(mode: .premium))
        XCTAssertEqual(result.images.count, 3, "premium モードは3枚")
        XCTAssertEqual(result.ratios, [.balanced, .fatherLeaning, .motherLeaning],
                       "比率の並びは入力順 (balanced→father→mother) で安定")
        let ids = await log.snapshotIDs()
        XCTAssertEqual(ids.count, 3, "3並列で3回呼ばれる")
    }

    func test_generate_premium_sendsDifferentPromptsPerRatio() async throws {
        let log = CallLog()
        let gen = MockImageGenerator(id: "G", behavior: .success(anyImage()), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: gen, style: .photorealistic)
        ])

        _ = try await orchestrator.generate(request: anyRequest(mode: .premium))
        let prompts = await log.snapshotPrompts()
        XCTAssertEqual(prompts.count, 3)
        let unique = Set(prompts)
        XCTAssertEqual(unique.count, 3, "3つのプロンプトはすべて異なる必要がある")
        XCTAssertTrue(prompts.contains { $0.contains("BALANCED") })
        XCTAssertTrue(prompts.contains { $0.contains("FATHER-LEANING") })
        XCTAssertTrue(prompts.contains { $0.contains("MOTHER-LEANING") })
    }

    func test_generate_premium_partialSuccess_returnsOnlySucceeded() async throws {
        let log = CallLog()
        // mother-leaning パイプラインだけ全アテンプト safetyBlock させる
        let gen = PerRatioMockGenerator(
            id: "G",
            behaviorByPromptKeyword: [
                "BALANCED":        .success(anyImage()),
                "FATHER-LEANING":  .success(anyImage()),
                "MOTHER-LEANING":  .throwing(.safetyBlocked(reason: "M"))
            ],
            log: log
        )
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: gen, style: .photorealistic)
        ])

        let result = try await orchestrator.generate(request: anyRequest(mode: .premium))
        XCTAssertEqual(result.images.count, 2, "成功した2枚のみ返す")
        XCTAssertEqual(result.ratios, [.balanced, .fatherLeaning],
                       "失敗した motherLeaning は除外され、残り2つの順序は保持")
    }

    func test_generate_premium_allFail_throws() async {
        let log = CallLog()
        let gen = MockImageGenerator(id: "G", behavior: .throwing(.safetyBlocked(reason: "X")), log: log)
        let orchestrator = GenerationOrchestrator(attempts: [
            .init(generator: gen, style: .photorealistic)
        ])

        do {
            _ = try await orchestrator.generate(request: anyRequest(mode: .premium))
            XCTFail("Should have thrown when all ratios fail")
        } catch is ImageGenerationError {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
