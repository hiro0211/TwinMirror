import Foundation
import UIKit

enum ChildGender: String, CaseIterable, Sendable {
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

struct ChildAge: Sendable, Hashable, Identifiable {
    let years: Int

    static let minYears = 0
    static let maxYears = 20
    static let allYears = Array(minYears...maxYears)
    static let `default` = ChildAge(years: 5)

    init(years: Int) {
        self.years = years
    }

    static func clamped(years: Int) -> ChildAge {
        ChildAge(years: min(maxYears, max(minYears, years)))
    }

    var id: Int { years }
    var displayName: String { "\(years)歳" }
    var isMajorTick: Bool { years % 5 == 0 }

    enum Bucket: Sendable, Equatable {
        case newborn      // 0–1
        case toddler      // 2–4
        case child        // 5–9
        case preteen      // 10–12
        case teen         // 13–17
        case youngAdult   // 18–20
    }

    var bucket: Bucket {
        switch years {
        case ...1:    return .newborn
        case 2...4:   return .toddler
        case 5...9:   return .child
        case 10...12: return .preteen
        case 13...17: return .teen
        default:      return .youngAdult
        }
    }
}

struct GenerationRequest: Sendable {
    let fatherImageData: Data
    let motherImageData: Data
    let gender: ChildGender
    let age: ChildAge

    init(
        fatherImageData: Data,
        motherImageData: Data,
        gender: ChildGender,
        age: ChildAge = .default
    ) {
        self.fatherImageData = fatherImageData
        self.motherImageData = motherImageData
        self.gender = gender
        self.age = age
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
