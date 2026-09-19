import SwiftUI

struct RepoListView: View {
    @EnvironmentObject var store: RepoStore

    var body: some View {
        NavigationView {
            List {
                ForEach(store.repos) { repo in
                    Text("\(repo.owner)/\(repo.name)")
                }
                .onDelete { idx in
                    idx.forEach { store.remove(store.repos[$0]) }
                }
            }
            .navigationTitle("RepoBox")
        }
    }
}