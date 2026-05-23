import Foundation
import UIKit
import SwiftUI

@MainActor
@Observable
final class ResultViewModel {
    enum Phase {
        case loading
        case done(GenerationResult)
        case failed(String)
    }

    var phase: Phase = .loading
    var savedToast: String?
    var gender: ChildGender

    let fatherImage: UIImage
    let motherImage: UIImage
    private var request: GenerationRequest
    private let orchestrator: GenerationOrchestrator
    private let saveService: PhotoSaving
    private let analytics: AnalyticsTracking
    private let reviewService: ReviewRequestService
    private let historyService: HistoryServicing?

    init(
        initialRequest: GenerationRequest,
        fatherImage: UIImage,
        motherImage: UIImage,
        saveService: PhotoSaving = PhotoSaveService(),
        analytics: AnalyticsTracking = DefaultAnalytics.shared,
        reviewService: ReviewRequestService = .shared,
        historyService: HistoryServicing? = HistoryService.makeDefault()
    ) {
        self.request = initialRequest
        self.gender = initialRequest.gender
        self.fatherImage = fatherImage
        self.motherImage = motherImage
        if let workerURL = AppConfig.workerURL {
            self.orchestrator = GenerationOrchestrator(
                workerURL: workerURL,
                authToken: AppConfig.workerAuthToken
            )
        } else {
            self.orchestrator = GenerationOrchestrator(attempts: [])
        }
        self.saveService = saveService
        self.analytics = analytics
        self.reviewService = reviewService
        self.historyService = historyService
    }

    func generate() async {
        phase = .loading
        let mode = request.mode.rawValue
        let startedAt = Date()
        analytics.track(.generationStarted(mode: mode))
        do {
            let result = try await orchestrator.generate(request: request)
            phase = .done(result)
            let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            analytics.track(.generationSucceeded(mode: mode, elapsedMs: elapsedMs, imageCount: result.images.count))
            persistHistory(result: result)
        } catch {
            phase = .failed(error.localizedDescription)
            analytics.track(.generationFailed(mode: mode, errorKind: String(describing: type(of: error))))
        }
    }

    func regenerate(with newGender: ChildGender) async {
        gender = newGender
        request = GenerationRequest(
            fatherImageData: request.fatherImageData,
            motherImageData: request.motherImageData,
            gender: newGender,
            age: request.age,
            mode: request.mode
        )
        analytics.track(.resultRegenerated(newGender: newGender.rawValue))
        await generate()
    }

    private func persistHistory(result: GenerationResult) {
        guard let historyService else { return }
        let image = result.bestImage
        let ratio = result.ratios.indices.contains(result.bestIndex) ? result.ratios[result.bestIndex] : nil
        let metadata = HistoryMetadata(
            gender: request.gender.rawValue,
            age: String(request.age.years),
            mode: request.mode.rawValue,
            style: result.usedStyle == .photorealistic ? "photorealistic" : "illustration",
            ratio: ratio?.rawValue,
            prompt: nil
        )
        let isPremium = PurchaseService.shared.isPremium
        let imageJPEG = image.jpegData(compressionQuality: 0.9) ?? Data()
        let thumb = Self.thumbnailJPEG(from: image, maxDimension: 512)
        guard !imageJPEG.isEmpty, !thumb.isEmpty else { return }

        Task.detached(priority: .utility) { [historyService, metadata, analytics] in
            do {
                _ = try await historyService.save(
                    imageJPEG: imageJPEG,
                    thumbnailJPEG: thumb,
                    metadata: metadata,
                    isPremium: isPremium
                )
            } catch {
                analytics.track(.resultSaveFailed(errorKind: "history_\(type(of: error))"))
            }
        }
    }

    private static func thumbnailJPEG(from image: UIImage, maxDimension: CGFloat) -> Data {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return Data() }
        let scale = min(1.0, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.7) ?? Data()
    }

    func saveCurrent(at index: Int) async {
        guard case .done(let result) = phase else { return }
        guard result.images.indices.contains(index) else { return }
        do {
            try await saveService.save(result.images[index])
            savedToast = "保存しました"
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            analytics.track(.resultSaved(index: index))
            reviewService.recordPositiveEvent()
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { savedToast = nil }
            }
        } catch {
            savedToast = error.localizedDescription
            analytics.track(.resultSaveFailed(errorKind: String(describing: type(of: error))))
        }
    }
}
