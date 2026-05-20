import Foundation
import UIKit

/// 画像生成のオーケストレータ。Gemini Nano Banana を1枚生成で叩く。
///
/// フォールバックチェーン:
///   1. Gemini 3.1 (Nano Banana 2) photorealistic
///   2. Gemini 2.5 photorealistic
///   3. Gemini 3.1 illustration（最後の砦）
struct GenerationOrchestrator {
    struct Attempt {
        let generator: any ImageGenerator
        let style: GenerationStyle
    }

    /// 1回の生成で要求する候補画像数。
    /// 本番は **1枚固定**（プレミアム削除 & コスト最適化）。
    static let candidateCount = 1

    let attempts: [Attempt]
    let promptBuilder: PromptBuilder

    /// Test seam: inject attempt list directly.
    init(attempts: [Attempt], promptBuilder: PromptBuilder = PromptBuilder()) {
        self.attempts = attempts
        self.promptBuilder = promptBuilder
    }

    /// Production convenience: build default chain from API keys.
    init(
        geminiKey: String,
        promptBuilder: PromptBuilder = PromptBuilder()
    ) {
        self.init(
            attempts: Self.defaultAttempts(geminiKey: geminiKey),
            promptBuilder: promptBuilder
        )
    }

    static func defaultAttempts(geminiKey: String) -> [Attempt] {
        [
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .nanoBanana2), style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .stable25),    style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .nanoBanana2), style: .illustration),
        ]
    }

    func generate(request: GenerationRequest, candidateCount: Int = GenerationOrchestrator.candidateCount) async throws -> GenerationResult {
        var lastError: Error?
        for attempt in attempts {
            do {
                let prompt = try promptBuilder.build(style: attempt.style, gender: request.gender, age: request.age)
                let images = try await attempt.generator.generate(request: request, prompt: prompt, count: candidateCount)
                guard !images.isEmpty else {
                    throw ImageGenerationError.noImageReturned
                }
                let bestIndex = pickBestIndex(from: images)
                return GenerationResult(images: images, bestIndex: bestIndex, usedStyle: attempt.style)
            } catch {
                lastError = error
                if let genErr = error as? ImageGenerationError, !genErr.isSafetyOrTransient {
                    if case .missingAPIKey = genErr {
                        continue
                    }
                    throw error
                }
                continue
            }
        }
        throw lastError ?? ImageGenerationError.allFallbacksExhausted
    }

    /// 1枚運用のため通常は index 0。複数返ってきた場合に備えて jpeg サイズで雑に選ぶ。
    func pickBestIndex(from images: [UIImage]) -> Int {
        var bestIndex = 0
        var bestSize = 0
        for (i, image) in images.enumerated() {
            let size = image.jpegData(compressionQuality: 0.9)?.count ?? 0
            if size > bestSize {
                bestSize = size
                bestIndex = i
            }
        }
        return bestIndex
    }
}
