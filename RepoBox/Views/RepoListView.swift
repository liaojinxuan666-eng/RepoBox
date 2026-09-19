import SwiftUI

struct RepoListView: View {
    @EnvironmentObject var store: RepoStore
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            List {
                ForEach(store.repos) { repo in
                    NavigationLink(destination: RepoDetailView(repo: repo)) {
                        VStack(alignment: .leading) {
                            Text("\(repo.owner)/\(repo.name)")
                            Text(repo.branch).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    idx.forEach { store.remove(store.repos[$0]) }
                }
            }
            .navigationTitle("RepoBox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddRepoView()
                    .environmentObject(store)
            }
        }
    }
}
