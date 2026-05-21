import Foundation

enum PromptBuilderError: Error {
    case templateNotFound(name: String)
}

struct PromptBuilder {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func build(style: GenerationStyle, gender: ChildGender, age: ChildAge, blendRatio: BlendRatio = .balanced) throws -> String {
        let templateName: String
        switch style {
        case .photorealistic: templateName = "child_realistic_v2"
        case .illustration:   templateName = "child_illustration_v2"
        }

        guard let url = bundle.url(forResource: templateName, withExtension: "txt"),
              let template = try? String(contentsOf: url, encoding: .utf8) else {
            throw PromptBuilderError.templateNotFound(name: templateName)
        }

        let blendBlock = try BlendPrompts.block(for: blendRatio, bundle: bundle)

        return template
            .replacingOccurrences(of: "{{GENDER}}", with: gender.promptValue)
            .replacingOccurrences(of: "{{AGE_BLOCK}}", with: ChildAgePrompts.block(for: age))
            .replacingOccurrences(of: "{{BLEND_BLOCK}}", with: blendBlock)
    }
}
