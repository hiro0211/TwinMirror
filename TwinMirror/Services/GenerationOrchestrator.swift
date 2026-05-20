import Foundation
import UIKit

/// 画像生成のオーケストレータ。
///
/// ユーザーが選んだ `GenerationQuality` で実行プロバイダが分岐する:
/// - `.fast`     : Gemini 3.1 Nano Banana 2 のみ（高速・無料枠で十分）。OpenAIキーがあっても無視。
/// - `.premium`  : OpenAI gpt-image-2 のみ。Geminiへの暗黙フォールバックなし。
///                 ただしOpenAIキーが未設定 / プレースホルダーの時は安全のためGeminiチェーンで代用。
///
/// `.fast` / OpenAI未設定時のGeminiチェーン:
///   1. Gemini 3.1 (Nano Banana 2) photorealistic
///   2. Gemini 2.5 photorealistic
///   3. Gemini 3.1 illustration (最後の砦)
struct GenerationOrchestrator {
    struct Attempt {
        let generator: any ImageGenerator
        let style: GenerationStyle
    }

    let attempts: [Attempt]
    let promptBuilder: PromptBuilder

    /// Test seam: inject attempt list directly.
    init(attempts: [Attempt], promptBuilder: PromptBuilder = PromptBuilder()) {
        self.attempts = attempts
        self.promptBuilder = promptBuilder
    }

    /// Production convenience: build default chain from API keys + quality.
    init(
        geminiKey: String,
        openAIKey: String,
        quality: GenerationQuality,
        promptBuilder: PromptBuilder = PromptBuilder()
    ) {
        self.init(
            attempts: Self.defaultAttempts(geminiKey: geminiKey, openAIKey: openAIKey, quality: quality),
            promptBuilder: promptBuilder
        )
    }

    static func defaultAttempts(
        geminiKey: String,
        openAIKey: String,
        quality: GenerationQuality
    ) -> [Attempt] {
        switch quality {
        case .fast:
            // 高速モード: Geminiチェーンのみ（OpenAIキーがあっても使わない）
            return geminiChain(geminiKey: geminiKey)

        case .premium:
            // プレミアムモード: OpenAI単独。キーが無効ならGeminiチェーンに代替。
            if !openAIKey.isEmpty && openAIKey != "REPLACE_WITH_YOUR_OPENAI_KEY_OR_EMPTY" {
                return [
                    Attempt(
                        generator: OpenAIImageGenerator(apiKey: openAIKey),
                        style: .photorealistic
                    )
                ]
            }
            return geminiChain(geminiKey: geminiKey)
        }
    }

    private static func geminiChain(geminiKey: String) -> [Attempt] {
        [
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .nanoBanana2), style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .stable25),    style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .nanoBanana2), style: .illustration),
        ]
    }

    func generate(request: GenerationRequest, candidateCount: Int = 3) async throws -> GenerationResult {
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
                // Only fall through to next attempt on safety/transient errors,
                // or when the current generator is unusable (missing key).
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

    /// Pick the image with the largest file size as a rough proxy for detail/quality.
    /// (TODO post-MVP: also run Vision face detection and prefer images with a single detected face.)
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
