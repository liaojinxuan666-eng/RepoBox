import SwiftUI

struct RemoteRepoPickerView: View {
    @EnvironmentObject var store: RepoStore
    @Environment(\.dismiss) var dismiss

    @State private var repos: [RemoteRepo] = []
    @State private var busy = false
    @State private var err = ""
    @State private var status = ""

    var body: some View {
        NavigationView {
            Group {
                if busy {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(status).font(.footnote).foregroundColor(.secondary)
                    }
                } else if !err.isEmpty {
                    Text(err).foregroundColor(.red).padding()
                } else {
                    List(repos) { r in
                        Button {
                            Task { await clone(r) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(r.owner)/\(r.name)")
                                        .foregroundColor(.primary)
                                    Text(r.defaultBranch)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if r.isPrivate {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("我的仓库")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    func load() async {
        guard let token = Keychain.githubToken else { err = "未登录"; return }
        busy = true; status = "加载仓库列表…"
        do {
            repos = try await GitHubClient(token: token).listRepos()
        } catch {
            err = error.localizedDescription
        }
        busy = false
    }

    func clone(_ r: RemoteRepo) async {
        guard let token = Keychain.githubToken else { return }
        busy = true; status = "克隆 \(r.name)…"
        do {
            let local = Repo(owner: r.owner, name: r.name, branch: r.defaultBranch)
            let api = GitHubAPI(token: token,
                                owner: r.owner, repo: r.name, branch: r.defaultBranch)
            try await api.clone(to: local.localDir)
            store.add(local)
            dismiss()
        } catch {
            err = "克隆失败: \(error.localizedDescription)"
            busy = false
        }
    }
}