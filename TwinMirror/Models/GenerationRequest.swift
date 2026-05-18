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

struct GenerationRequest: Sendable {
    let fatherImageData: Data
    let motherImageData: Data
    let gender: BabyGender
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
