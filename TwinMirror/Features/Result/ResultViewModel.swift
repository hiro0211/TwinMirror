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

    init(
        initialRequest: GenerationRequest,
        fatherImage: UIImage,
        motherImage: UIImage,
        saveService: PhotoSaving = PhotoSaveService(),
        analytics: AnalyticsTracking = DefaultAnalytics.shared
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

    func saveCurrent(at index: Int) async {
        guard case .done(let result) = phase else { return }
        guard result.images.indices.contains(index) else { return }
        do {
            try await saveService.save(result.images[index])
            savedToast = "保存しました"
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            analytics.track(.resultSaved(index: index))
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
