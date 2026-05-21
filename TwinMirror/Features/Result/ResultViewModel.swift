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

    init(
        initialRequest: GenerationRequest,
        fatherImage: UIImage,
        motherImage: UIImage,
        saveService: PhotoSaving = PhotoSaveService()
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
    }

    func generate() async {
        phase = .loading
        do {
            let result = try await orchestrator.generate(request: request)
            phase = .done(result)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func regenerate(with newGender: ChildGender) async {
        gender = newGender
        request = GenerationRequest(
            fatherImageData: request.fatherImageData,
            motherImageData: request.motherImageData,
            gender: newGender,
            age: request.age
        )
        await generate()
    }

    func saveCurrent(at index: Int) async {
        guard case .done(let result) = phase else { return }
        guard result.images.indices.contains(index) else { return }
        do {
            try await saveService.save(result.images[index])
            savedToast = "保存しました"
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { savedToast = nil }
            }
        } catch {
            savedToast = error.localizedDescription
        }
    }
}
