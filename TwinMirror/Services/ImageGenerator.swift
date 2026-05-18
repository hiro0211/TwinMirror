import Foundation
import UIKit

enum ImageGenerationError: Error, LocalizedError {
    case missingAPIKey
    case requestFailed(statusCode: Int, body: String)
    case safetyBlocked(reason: String)
    case noImageReturned
    case decodingFailed
    case allFallbacksExhausted

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが設定されていません。"
        case .requestFailed(let code, let body):
            return "リクエスト失敗 (\(code)): \(body.prefix(200))"
        case .safetyBlocked(let reason):
            return "安全フィルタにブロックされました: \(reason)"
        case .noImageReturned:
            return "画像が返却されませんでした。"
        case .decodingFailed:
            return "応答の解析に失敗しました。"
        case .allFallbacksExhausted:
            return "生成できませんでした。別の写真でお試しください。"
        }
    }

    var isSafetyOrTransient: Bool {
        switch self {
        case .safetyBlocked, .noImageReturned: return true
        case .requestFailed(let code, _): return code == 400 || code == 429 || code >= 500
        default: return false
        }
    }
}

protocol ImageGenerator: Sendable {
    /// Generates `count` candidate images for the given request and prompt.
    /// Returns the actual images (not URLs) so the caller can pick a best one.
    func generate(request: GenerationRequest, prompt: String, count: Int) async throws -> [UIImage]
}
