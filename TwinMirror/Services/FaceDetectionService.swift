import Foundation
import UIKit
import Vision

enum FaceDetectionError: Error, LocalizedError {
    case noFaceDetected
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .noFaceDetected:
            return "顔が検出できませんでした。正面を向いた、目・鼻・口がはっきり見える写真をお選びください。"
        case .invalidImage:
            return "画像の読み込みに失敗しました。別の写真でお試しください。"
        }
    }
}

struct DetectedFace: Sendable {
    let boundingBox: CGRect
    let imageSize: CGSize
}

actor FaceDetectionService {
    func detectLargestFace(in image: UIImage) async throws -> DetectedFace {
        guard let cgImage = image.cgImage else {
            throw FaceDetectionError.invalidImage
        }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation, options: [:])

        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw FaceDetectionError.noFaceDetected
        }

        let largest = observations.max { lhs, rhs in
            (lhs.boundingBox.width * lhs.boundingBox.height) < (rhs.boundingBox.width * rhs.boundingBox.height)
        }!

        return DetectedFace(
            boundingBox: largest.boundingBox,
            imageSize: CGSize(width: cgImage.width, height: cgImage.height)
        )
    }
}

private extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
