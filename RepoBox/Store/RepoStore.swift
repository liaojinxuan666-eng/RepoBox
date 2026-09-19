import Foundation

struct Repo: Codable, Identifiable {
    var id = UUID()
    let owner: String
    let name: String
    let branch: String

    var localDir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("repos")
            .appendingPathComponent("\(owner)_\(name)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
}

final class RepoStore: ObservableObject {
    @Published var repos: [Repo] = []
    private let key = "repobox.repos"

    init() { load() }

    func add(_ r: Repo) { repos.append(r); save() }

    func remove(_ r: Repo) {
        try? FileManager.default.removeItem(at: r.localDir)
        repos.removeAll { $0.id == r.id }
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(repos) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let r = try? JSONDecoder().decode([Repo].self, from: d) {
            repos = r
        }
    }
}