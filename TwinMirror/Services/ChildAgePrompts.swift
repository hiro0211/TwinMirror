import Foundation

/// `ChildAge` をプロンプトの `{{AGE_BLOCK}}` に展開するユーティリティ。
/// 21年齢ぶんのテンプレートを管理する代わりに、6つのバケットへマッピングして
/// 年齢数字をテンプレに差し込む方式を採る。
enum ChildAgePrompts {

    static func block(for age: ChildAge) -> String {
        let years = age.years
        switch age.bucket {
        case .newborn:
            return """
            AGE: This is a newborn / very young infant, age \(years) (around \(years == 0 ? "2–3 months" : "12 months")). \
            Soft round cheeks, large eyes, fine wispy hair, smooth peachy skin, swaddled in a plain off-white blanket. \
            Realistic newborn proportions (large head, small chin, chubby cheeks). \
            Photorealistic skin texture appropriate for a newborn (soft, slightly translucent).
            """

        case .toddler:
            return """
            AGE: This is a toddler, age \(years) years old. \
            Round face with baby-fat cheeks softening, large curious eyes, the beginning of an adult-style smile, \
            age-appropriate haircut, casual neutral-color age-appropriate clothing.
            """

        case .child:
            return """
            AGE: This is a young child, age \(years) years old (kindergarten to early elementary school). \
            Defined facial features beginning to emerge from baby-fat softness, small adult-style teeth visible in a gentle smile, \
            age-appropriate haircut, casual neutral-color t-shirt.
            """

        case .preteen:
            return """
            AGE: This is a pre-teen, age \(years) years old (upper elementary). \
            Balanced child proportions, smooth skin with no acne, alert curious expression, \
            age-appropriate haircut, casual neutral clothing.
            """

        case .teen:
            return """
            AGE: This is a teenager, age \(years) years old. \
            Adolescent facial proportions, clear but realistic teen skin, modern age-appropriate haircut, \
            neutral clothing. Match the expression and styling to the GENDER above without hyper-stylization.
            """

        case .youngAdult:
            return """
            AGE: This is a young adult, age \(years) years old. \
            Fully defined adult facial structure, clear adult complexion, natural expression, \
            age-appropriate styling, neutral background. Still recognizably the genetic child of the two reference adults.
            """
        }
    }
}
