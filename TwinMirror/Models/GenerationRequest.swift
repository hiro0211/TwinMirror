import Foundation
import UIKit

enum BabyGender: String, CaseIterable, Sendable {
    case female
    case male
    case unspecified

    var displayName: String {
        switch self {
        case .female: return "女の子"
        case .male: return "男の子"
        case .unspecified: return "おまかせ"
        }
    }

    var promptValue: String {
        switch self {
        case .female: return "female"
        case .male: return "male"
        case .unspecified: return "unspecified — let the model decide"
        }
    }
}

enum GenerationQuality: String, CaseIterable, Sendable {
    /// Gemini Nano Banana 2 ベース。10秒前後で生成。
    case fast
    /// OpenAI gpt-image-2 ベース。1〜2分かけて高画質に仕上げる。
    case premium

    var displayName: String {
        switch self {
        case .fast: return "高速モード"
        case .premium: return "プレミアムモード"
        }
    }

    var subtitle: String {
        switch self {
        case .fast: return "約10秒でサクッと生成"
        case .premium: return "1〜2分かけて高画質に仕上げる"
        }
    }

    var systemImage: String {
        switch self {
        case .fast: return "bolt.fill"
        case .premium: return "sparkles"
        }
    }

    /// このモードで生成する候補画像数。
    /// プレミアムは高画質1枚（gpt-image-2 × n=3 は 3〜5分かかるため）。
    /// 高速は3枚生成してカルーセルで見比べられるようにする。
    var candidateCount: Int {
        switch self {
        case .fast: return 3
        case .premium: return 1
        }
    }
}

struct GenerationRequest: Sendable {
    let fatherImageData: Data
    let motherImageData: Data
    let gender: BabyGender
    let quality: GenerationQuality

    init(
        fatherImageData: Data,
        motherImageData: Data,
        gender: BabyGender,
        quality: GenerationQuality = .fast
    ) {
        self.fatherImageData = fatherImageData
        self.motherImageData = motherImageData
        self.gender = gender
        self.quality = quality
    }
}

struct GenerationResult: Sendable {
    let images: [UIImage]
    let bestIndex: Int
    let usedStyle: GenerationStyle

    var bestImage: UIImage {
        images[bestIndex]
    }
}

enum GenerationStyle: Sendable {
    case photorealistic
    case illustration
}
