import SwiftUI

@main
struct RepoBoxApp: App {
    @StateObject private var store = RepoStore()

    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: RepoStore

    var body: some View {
        Group {
            if store.isLoggedIn {
                RepoListView()
            } else {
                LoginView()
            }
        }
    }
}