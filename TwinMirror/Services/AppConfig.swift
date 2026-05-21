import Foundation

enum AppConfig {
    static var workerURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "WORKER_URL") as? String,
              !raw.isEmpty,
              !raw.hasPrefix("REPLACE_"),
              let url = URL(string: raw) else {
            return nil
        }
        return url
    }

    static var workerAuthToken: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "WORKER_AUTH_TOKEN") as? String ?? ""
        return raw.hasPrefix("REPLACE_") ? "" : raw
    }

    static let termsURL = URL(string: "https://hiro0211.github.io/TwinMirror/terms.html")!
    static let privacyURL = URL(string: "https://hiro0211.github.io/TwinMirror/privacy.html")!
}
