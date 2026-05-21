import Foundation

enum BlendRatio: String, CaseIterable, Sendable, Equatable {
    case balanced
    case fatherLeaning
    case motherLeaning

    var fatherPercent: Int {
        switch self {
        case .balanced:      return 50
        case .fatherLeaning: return 70
        case .motherLeaning: return 30
        }
    }

    var motherPercent: Int { 100 - fatherPercent }

    var displayLabel: String {
        switch self {
        case .balanced:      return "両親半々"
        case .fatherLeaning: return "お父さん似"
        case .motherLeaning: return "お母さん似"
        }
    }
}

enum GenerationMode: String, Sendable, Equatable {
    case fast
    case premium

    var blendRatios: [BlendRatio] {
        switch self {
        case .fast:    return [.balanced]
        case .premium: return [.balanced, .fatherLeaning, .motherLeaning]
        }
    }
}
