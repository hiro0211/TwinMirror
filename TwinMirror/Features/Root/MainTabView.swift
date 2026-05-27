import SwiftUI

struct MainTabView: View {
    enum TabValue: Hashable {
        case home
        case history
        case settings
    }

    @State private var selection: TabValue = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("ホーム", systemImage: "sparkles", value: TabValue.home) {
                NavigationStack {
                    ComposeView()
                }
            }
            Tab("履歴", systemImage: "photo.stack", value: TabValue.history) {
                HistoryView()
            }
            Tab("設定", systemImage: "gearshape", value: TabValue.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
