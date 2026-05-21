import Foundation
import UIKit

struct GenerationOrchestrator {
    struct Attempt {
        let generator: any ImageGenerator
        let style: GenerationStyle
    }

    static let candidateCount = 1

    let attempts: [Attempt]
    let promptBuilder: PromptBuilder

    init(attempts: [Attempt], promptBuilder: PromptBuilder = PromptBuilder()) {
        self.attempts = attempts
        self.promptBuilder = promptBuilder
    }

    init(
        workerURL: URL,
        authToken: String,
        promptBuilder: PromptBuilder = PromptBuilder()
    ) {
        self.init(
            attempts: Self.defaultAttempts(workerURL: workerURL, authToken: authToken),
            promptBuilder: promptBuilder
        )
    }

    static func defaultAttempts(workerURL: URL, authToken: String) -> [Attempt] {
        [
            Attempt(generator: GeminiImageGenerator(workerURL: workerURL, authToken: authToken, model: .nanoBanana2), style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(workerURL: workerURL, authToken: authToken, model: .stable25),    style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(workerURL: workerURL, authToken: authToken, model: .nanoBanana2), style: .illustration),
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
