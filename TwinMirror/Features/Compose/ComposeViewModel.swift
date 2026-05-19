import Foundation
import UIKit
import SwiftUI

@MainActor
@Observable
final class ComposeViewModel {
    enum ParentSlot {
        case father
        case mother

        var label: String {
            switch self {
            case .father: return "お父さん"
            case .mother: return "お母さん"
            }
        }
    }

    var fatherImage: UIImage?
    var motherImage: UIImage?
    var fatherFace: DetectedFace?
    var motherFace: DetectedFace?
    var gender: BabyGender = .unspecified
    var quality: GenerationQuality = .fast
    var errorMessage: String?
    var isProcessingFace: Bool = false

    private let faceService = FaceDetectionService()
    private let preprocessor = ImagePreprocessor()

    var canGenerate: Bool {
        fatherImage != nil && motherImage != nil && fatherFace != nil && motherFace != nil
    }

    func setImage(_ image: UIImage, for slot: ParentSlot) async {
        isProcessingFace = true
        errorMessage = nil
        defer { isProcessingFace = false }
        do {
            let face = try await faceService.detectLargestFace(in: image)
            switch slot {
            case .father:
                fatherImage = image
                fatherFace = face
            case .mother:
                motherImage = image
                motherFace = face
            }
        } catch {
            errorMessage = error.localizedDescription
            switch slot {
            case .father: fatherImage = nil; fatherFace = nil
            case .mother: motherImage = nil; motherFace = nil
            }
        }
    }

    func clear(slot: ParentSlot) {
        switch slot {
        case .father:
            fatherImage = nil
            fatherFace = nil
        case .mother:
            motherImage = nil
            motherFace = nil
        }
    }

    func buildGenerationRequest() -> GenerationRequest? {
        guard let fatherImage, let motherImage, let fatherFace, let motherFace else { return nil }
        guard let fatherData = preprocessor.process(image: fatherImage, face: fatherFace) else { return nil }
        guard let motherData = preprocessor.process(image: motherImage, face: motherFace) else { return nil }
        return GenerationRequest(
            fatherImageData: fatherData,
            motherImageData: motherData,
            gender: gender,
            quality: quality
        )
    }
}
