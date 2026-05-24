import SwiftUI

/// アプリのルート。
/// 初回起動かどうかで `WelcomeView` / `MainTabView` を切り替える。
struct RootView: View {
    @AppStorage("twinmirror.welcome.completed") private var welcomeCompleted = false

    var body: some View {
        if welcomeCompleted {
            MainTabView()
        } else {
            WelcomeView(onContinue: {
                welcomeCompleted = true
            })
        }
    }
}

#Preview {
    RootView()
}
