import Foundation

enum BlendPromptsError: Error {
    case templateNotFound(name: String)
}

/// `BlendRatio` をプロンプトの `{{BLEND_BLOCK}}` に展開するユーティリティ。
/// 各比率に対応する `.txt` テンプレートを Resources/Prompts から読み込む。
enum BlendPrompts {

    static func block(for ratio: BlendRatio, bundle: Bundle = .main) throws -> String {
        let name = templateName(for: ratio)
        guard let url = bundle.url(forResource: name, withExtension: "txt"),
              let template = try? String(contentsOf: url, encoding: .utf8) else {
            throw BlendPromptsError.templateNotFound(name: name)
        }
        return template.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func templateName(for ratio: BlendRatio) -> String {
        switch ratio {
        case .balanced:      return "blend_block_balanced"
        case .fatherLeaning: return "blend_block_father_leaning"
        case .motherLeaning: return "blend_block_mother_leaning"
        }
    }
}
