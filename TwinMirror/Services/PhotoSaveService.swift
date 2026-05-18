import Foundation
import UIKit
import Photos

enum PhotoSaveError: Error, LocalizedError {
    case unauthorized
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "写真ライブラリへのアクセスが許可されていません。設定から許可してください。"
        case .saveFailed(let error):
            return "保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

struct PhotoSaveService {
    func save(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoSaveError.unauthorized
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else if let error {
                    continuation.resume(throwing: PhotoSaveError.saveFailed(underlying: error))
                } else {
                    continuation.resume(throwing: PhotoSaveError.saveFailed(underlying: NSError(domain: "PhotoSave", code: -1)))
                }
            }
        }
    }
}
