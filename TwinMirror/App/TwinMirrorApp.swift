import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct TwinMirrorApp: App {
    init() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
        MainActor.assumeIsolated {
            PurchaseService.shared.bootstrap()
            ReviewRequestService.shared.bootstrap()
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
