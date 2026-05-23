import SwiftUI

struct MainTabView: View {
    enum TabValue: Hashable {
        case home
        case history
    }

    @State private var selection: TabValue = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("ホーム", systemImage: "sparkles", value: TabValue.home) {
                HomeView()
            }
            Tab("履歴", systemImage: "photo.stack", value: TabValue.history) {
                HistoryView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
