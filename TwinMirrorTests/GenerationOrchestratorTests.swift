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

    // MARK: - default chain composition (Gemini only)

    func test_defaultAttempts_usesGeminiOnly() {
        let attempts = GenerationOrchestrator.defaultAttempts(workerURL: URL(string: "https://worker.example.com")!, authToken: "tok")
        XCTAssertTrue(attempts.allSatisfy { $0.generator is GeminiImageGenerator },
                      "本番チェーンはGeminiのみで構成される（OpenAIは削除済み）")
        XCTAssertGreaterThanOrEqual(attempts.count, 1)
    }

    func test_defaultAttempts_firstIsNanoBananaPhotoreal() {
        let attempts = GenerationOrchestrator.defaultAttempts(workerURL: URL(string: "https://worker.example.com")!, authToken: "tok")
        XCTAssertEqual(attempts.first?.style, .photorealistic,
                       "1番目は Nano Banana 2 の photorealistic")
    }

    func test_defaultAttempts_lastIsIllustration() {
        let attempts = GenerationOrchestrator.defaultAttempts(workerURL: URL(string: "https://worker.example.com")!, authToken: "tok")
        XCTAssertEqual(attempts.last?.style, .illustration,
                       "最後の砦は illustration スタイル")
    }

    // MARK: - candidate count default

    func test_candidateCount_defaultIsOne() {
        XCTAssertEqual(GenerationOrchestrator.candidateCount, 1,
                       "1リクエストあたり1枚生成（コスト最適化）")
    }

    // MARK: - generate behavior

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
