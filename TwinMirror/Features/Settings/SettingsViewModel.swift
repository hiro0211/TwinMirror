import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    private let historyService: HistoryServicing?
    private let isPremiumProvider: @Sendable () -> Bool

    private(set) var isClearingHistory = false
    private(set) var didClearAll = false
    var errorMessage: String?

    init(
        historyService: HistoryServicing? = HistoryService.makeDefault(),
        isPremiumProvider: @escaping @Sendable () -> Bool = { MainActor.assumeIsolated { PurchaseService.shared.isPremium } }
    ) {
        self.historyService = historyService
        self.isPremiumProvider = isPremiumProvider
    }

    var appVersionDisplay: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    func clearAllHistory() async {
        guard let service = historyService else {
            errorMessage = "履歴を削除できません（接続が設定されていません）"
            return
        }
        isClearingHistory = true
        errorMessage = nil
        do {
            try await service.deleteAll(isPremium: isPremiumProvider())
            didClearAll = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isClearingHistory = false
    }
}
