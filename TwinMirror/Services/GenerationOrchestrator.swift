import Foundation
import UIKit

protocol GenerationOrchestrating: Sendable {
    func generate(request: GenerationRequest) async throws -> GenerationResult
}

struct GenerationOrchestrator: GenerationOrchestrating, Sendable {
    struct Attempt: Sendable {
        let generator: any ImageGenerator
        let style: GenerationStyle
    }

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
            Attempt(generator: GeminiImageGenerator(workerURL: workerURL, authToken: authToken, model: .proImage),    style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(workerURL: workerURL, authToken: authToken, model: .nanoBanana2), style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(workerURL: workerURL, authToken: authToken, model: .stable25),    style: .photorealistic),
            Attempt(generator: GeminiImageGenerator(workerURL: workerURL, authToken: authToken, model: .nanoBanana2), style: .illustration),
        ]
    }

    /// Generates one image per `request.mode.blendRatios`. Each blend ratio runs
    /// its own independent fallback chain in parallel. Returns whatever subset
    /// of ratios succeeded — only throws when **all** ratios failed.
    func generate(request: GenerationRequest) async throws -> GenerationResult {
        let ratios = request.mode.blendRatios

        // Pre-build prompts synchronously so we don't have to send the
        // PromptBuilder/Bundle across concurrent task boundaries.
        let pipelines: [Pipeline] = try ratios.map { ratio in
            let steps = try attempts.map { attempt -> Pipeline.Step in
                let prompt = try promptBuilder.build(
                    style: attempt.style,
                    gender: request.gender,
                    age: request.age,
                    blendRatio: ratio
                )
                return Pipeline.Step(generator: attempt.generator, style: attempt.style, prompt: prompt)
            }
            return Pipeline(ratio: ratio, steps: steps)
        }

        let outcomes = await withTaskGroup(of: PipelineOutcome.self) { group -> [PipelineOutcome] in
            for (index, pipeline) in pipelines.enumerated() {
                group.addTask {
                    await Self.runPipeline(index: index, pipeline: pipeline, request: request)
                }
            }
            var collected: [PipelineOutcome] = []
            for await outcome in group { collected.append(outcome) }
            return collected
        }

        // Reassemble in input order — TaskGroup yields by completion order.
        var byIndex: [Int: (UIImage, BlendRatio, GenerationStyle)] = [:]
        var lastError: ImageGenerationError?
        for outcome in outcomes {
            switch outcome.result {
            case .success(let image, let style):
                byIndex[outcome.index] = (image, outcome.ratio, style)
            case .failure(let err):
                lastError = err
            }
        }

        var images: [UIImage] = []
        var orderedRatios: [BlendRatio] = []
        var usedStyle: GenerationStyle = .photorealistic
        for i in 0..<ratios.count {
            if let (img, r, s) = byIndex[i] {
                images.append(img)
                orderedRatios.append(r)
                usedStyle = s
            }
        }

        guard !images.isEmpty else {
            throw lastError ?? ImageGenerationError.allFallbacksExhausted
        }

        return GenerationResult(
            images: images,
            bestIndex: pickBestIndex(from: images),
            usedStyle: usedStyle,
            ratios: orderedRatios
        )
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

    private static func runPipeline(
        index: Int,
        pipeline: Pipeline,
        request: GenerationRequest
    ) async -> PipelineOutcome {
        var lastError: ImageGenerationError = .allFallbacksExhausted
        for step in pipeline.steps {
            do {
                let image = try await step.generator.generate(request: request, prompt: step.prompt)
                return PipelineOutcome(index: index, ratio: pipeline.ratio, result: .success(image, step.style))
            } catch let err as ImageGenerationError {
                lastError = err
                if !err.isSafetyOrTransient {
                    if case .missingAPIKey = err { continue }
                    return PipelineOutcome(index: index, ratio: pipeline.ratio, result: .failure(err))
                }
                continue
            } catch {
                lastError = .allFallbacksExhausted
                continue
            }
        }
        return PipelineOutcome(index: index, ratio: pipeline.ratio, result: .failure(lastError))
    }
}

private struct Pipeline: Sendable {
    struct Step: Sendable {
        let generator: any ImageGenerator
        let style: GenerationStyle
        let prompt: String
    }
    let ratio: BlendRatio
    let steps: [Step]
}

private struct PipelineOutcome: Sendable {
    enum Result: Sendable {
        case success(UIImage, GenerationStyle)
        case failure(ImageGenerationError)
    }
    let index: Int
    let ratio: BlendRatio
    let result: Result
}
