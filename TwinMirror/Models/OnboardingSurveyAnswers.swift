import Foundation

/// オンボーディングアンケートの設問1：年齢層。
enum AgeBracket: String, CaseIterable, Sendable {
    case under25
    case age25to34
    case age35to44
    case age45plus

    /// Firebase Analytics に送る値。外部分析との契約値なので変更不可。
    var analyticsValue: String {
        switch self {
        case .under25:    return "under_25"
        case .age25to34:  return "25_34"
        case .age35to44:  return "35_44"
        case .age45plus:  return "45_plus"
        }
    }

    var displayLabel: String {
        switch self {
        case .under25:    return "〜24歳"
        case .age25to34:  return "25〜34歳"
        case .age35to44:  return "35〜44歳"
        case .age45plus:  return "45歳〜"
        }
    }
}

/// 設問2：このアプリをどこで知ったか（HDYHAU 自己申告アトリビューション）。
enum AcquisitionSource: String, CaseIterable, Sendable {
    case appStore
    case social
    case wordOfMouth
    case media
    case ad
    case other

    var analyticsValue: String {
        switch self {
        case .appStore:     return "app_store"
        case .social:       return "social"
        case .wordOfMouth:  return "word_of_mouth"
        case .media:        return "media"
        case .ad:           return "ad"
        case .other:        return "other"
        }
    }

    var displayLabel: String {
        switch self {
        case .appStore:     return "App Store で見つけて"
        case .social:       return "SNS（Instagram / TikTok / X）"
        case .wordOfMouth:  return "友人・家族から聞いて"
        case .media:        return "ブログ・記事・YouTube"
        case .ad:           return "広告"
        case .other:        return "その他"
        }
    }

    var iconName: String {
        switch self {
        case .appStore:     return "applelogo"
        case .social:       return "person.2.wave.2.fill"
        case .wordOfMouth:  return "bubble.left.and.bubble.right.fill"
        case .media:        return "newspaper.fill"
        case .ad:           return "megaphone.fill"
        case .other:        return "ellipsis.circle.fill"
        }
    }
}

/// 設問3：どんな目的で使いたいか。
enum UseCase: String, CaseIterable, Sendable {
    case imagineWithPartner
    case enjoyWithPartner
    case entertainment
    case curiosity

    var analyticsValue: String {
        switch self {
        case .imagineWithPartner: return "imagine_with_partner"
        case .enjoyWithPartner:   return "enjoy_with_partner"
        case .entertainment:      return "entertainment"
        case .curiosity:          return "curiosity"
        }
    }

    var displayLabel: String {
        switch self {
        case .imagineWithPartner: return "パートナーとの未来の子どもを想像したい"
        case .enjoyWithPartner:   return "夫婦・カップルで一緒に楽しみたい"
        case .entertainment:      return "友達や家族とエンタメとして"
        case .curiosity:          return "興味本位で試してみたい"
        }
    }

    var iconName: String {
        switch self {
        case .imagineWithPartner: return "heart.fill"
        case .enjoyWithPartner:   return "person.2.fill"
        case .entertainment:      return "sparkles"
        case .curiosity:          return "lightbulb.fill"
        }
    }
}

/// 3 問の回答を保持する集約構造体。
struct OnboardingSurveyAnswers: Equatable, Sendable {
    var age: AgeBracket?
    var source: AcquisitionSource?
    var useCase: UseCase?

    /// 全ての設問に回答済みか。
    var isComplete: Bool {
        age != nil && source != nil && useCase != nil
    }
}
