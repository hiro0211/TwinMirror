import Foundation

enum AppConfig {
    static var geminiAPIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String ?? ""
    }

    static let termsURL = URL(string: "https://hiro0211.github.io/TwinMirror/terms.html")!
    static let privacyURL = URL(string: "https://hiro0211.github.io/TwinMirror/privacy.html")!
}
