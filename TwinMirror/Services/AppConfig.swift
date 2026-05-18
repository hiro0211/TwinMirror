import Foundation

enum AppConfig {
    static var geminiAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String ?? ""
    }

    static var openAIAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }

    static let termsURL = URL(string: "https://twinmirror.app/terms")!
    static let privacyURL = URL(string: "https://twinmirror.app/privacy")!
}
