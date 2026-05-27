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

    static var revenueCatAPIKey: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String ?? ""
        return raw.hasPrefix("REPLACE_") ? "" : raw
    }

    static let termsURL = URL(string: "https://hiro0211.github.io/TwinMirror/terms.html")!
    static let privacyURL = URL(string: "https://hiro0211.github.io/TwinMirror/privacy.html")!

    /// App Store Connect で発行された ID（MEMORY.md 確認済み）。
    static let appStoreID = "6771413156"

    /// レビュー記入画面に直接遷移するディープリンク。
    /// `action=write-review` で App Store / Safari がレビュー作成 UI を開く。
    static let appStoreWriteReviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!

    /// 満足度が低かったユーザー向けのフィードバック送信先。
    /// App Store のレビューに低評価を残されるより、メールで直接受け取って改善した方が建設的。
    static let feedbackMailtoURL = URL(string: "mailto:appsupport0326@gmail.com?subject=ツインミラーへのご意見")!
}
