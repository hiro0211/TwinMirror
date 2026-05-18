import Foundation

enum PromptBuilderError: Error {
    case templateNotFound(name: String)
}

struct PromptBuilder {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func build(style: GenerationStyle, gender: BabyGender) throws -> String {
        let templateName: String
        switch style {
        case .photorealistic: templateName = "baby_realistic_v1"
        case .illustration:   templateName = "baby_illustration_v1"
        }

        guard let url = bundle.url(forResource: templateName, withExtension: "txt"),
              let template = try? String(contentsOf: url, encoding: .utf8) else {
            throw PromptBuilderError.templateNotFound(name: templateName)
        }

        return template.replacingOccurrences(of: "{{GENDER}}", with: gender.promptValue)
    }
}
