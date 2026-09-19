import SwiftUI

@main
struct RepoBoxApp: App {
    @StateObject private var store = RepoStore()

    var body: some Scene {
        WindowGroup {
            RepoListView()
                .environmentObject(store)
        }
    }
}