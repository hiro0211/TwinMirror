import Foundation
import UIKit

/// Orchestrates the fallback chain:
/// 1. Gemini 3.1 (Nano Banana 2) + photorealistic
/// 2. Gemini 3.1 + illustration
/// 3. Gemini 2.5 + illustration
/// 4. OpenAI gpt-image-2 + illustration
struct GenerationOrchestrator {
    let geminiKey: String
    let openAIKey: String
    let promptBuilder: PromptBuilder

    init(geminiKey: String, openAIKey: String, promptBuilder: PromptBuilder = PromptBuilder()) {
        self.geminiKey = geminiKey
        self.openAIKey = openAIKey
        self.promptBuilder = promptBuilder
    }

    func generate(request: GenerationRequest, candidateCount: Int = 3) async throws -> GenerationResult {
        struct Attempt {
            let generator: any ImageGenerator
            let style: GenerationStyle
        }

        var attempts: [Attempt] = [
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .nanoBanana2), style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .nanoBanana2), style: .illustration),
            Attempt(generator: GeminiImageGenerator(apiKey: geminiKey, model: .stable25),    style: .illustration)
        ]
        if !openAIKey.isEmpty && openAIKey != "REPLACE_WITH_YOUR_OPENAI_KEY_OR_EMPTY" {
            attempts.append(Attempt(generator: OpenAIImageGenerator(apiKey: openAIKey), style: .illustration))
        }

        var lastError: Error?
        for attempt in attempts {
            do {
                let prompt = try promptBuilder.build(style: attempt.style, gender: request.gender)
                let images = try await attempt.generator.generate(request: request, prompt: prompt, count: candidateCount)
                guard !images.isEmpty else {
                    throw ImageGenerationError.noImageReturned
                }
                let bestIndex = pickBestIndex(from: images)
                return GenerationResult(images: images, bestIndex: bestIndex, usedStyle: attempt.style)
            } catch {
                lastError = error
                // Only fall through to next attempt on safety/transient errors.
                if let genErr = error as? ImageGenerationError, !genErr.isSafetyOrTransient {
                    if case .missingAPIKey = genErr {
                        // Hard stop — no point trying other generators that use the same missing key
                        // unless next generator is a different vendor.
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
