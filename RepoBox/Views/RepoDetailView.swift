import SwiftUI
import UniformTypeIdentifiers

struct RepoDetailView: View {
    let repo: Repo
    @State private var files: [String] = []
    @State private var status = ""
    @State private var busy = false
    @State private var showPicker = false

    var body: some View {
        List {
            if busy || !status.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        if busy { ProgressView() }
                        Text(status)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }

            ForEach(groupedKeys, id: \.self) { folder in
                Section(header: Text(folder.isEmpty ? "根目录" : folder)) {
                    ForEach(grouped[folder] ?? [], id: \.self) { f in
                        Text((f as NSString).lastPathComponent)
                            .font(.system(.footnote, design: .monospaced))
                    }
                }
            }
        }
        .navigationTitle("\(repo.owner)/\(repo.name)")
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Clone") { Task { await doClone() } }
                Button("导入 zip") { showPicker = true }
                Button("提交推送") { Task { await doCommit() } }
            }
        }
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: [.zip],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await importZip(url) }
            }
        }
        .task { refreshFiles() }
    }

    // MARK: - 分组

    private var grouped: [String: [String]] {
        Dictionary(grouping: files) { f in
            let comps = f.split(separator: "/")
            return comps.count > 1 ? comps.dropLast().joined(separator: "/") : ""
        }
    }

    private var groupedKeys: [String] {
        grouped.keys.sorted { a, b in
            if a.isEmpty { return true }
            if b.isEmpty { return false }
            return a.localizedStandardCompare(b) == .orderedAscending
        }
    }

    // MARK: - API

    private var api: GitHubAPI {
        GitHubAPI(token: Keychain.githubToken ?? "",
                  owner: repo.owner, repo: repo.name, branch: repo.branch)
    }

    private func refreshFiles() {
        let dir = repo.localDir.resolvingSymlinksInPath()
        var out: [String] = []
        if let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) {
            for case let url as URL in en {
                if url.hasDirectoryPath { continue }
                let rel = url.resolvingSymlinksInPath().path
                    .replacingOccurrences(of: dir.path + "/", with: "")
                if rel.hasPrefix(".git/") { continue }
                out.append(rel)
            }
        }
        files = out.sorted()
    }

    private func doClone() async {
        busy = true; status = "克隆中…"
        do {
            try await api.clone(to: repo.localDir)
            refreshFiles()
            status = "克隆完成，共 \(files.count) 个文件"
        } catch {
            status = "克隆失败: \(error.localizedDescription)"
        }
        busy = false
    }

    private func importZip(_ url: URL) async {
        busy = true; status = "解压中…"
        do {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            try ZipImporter.extract(url, to: repo.localDir, stripFirstComponent: true)
            refreshFiles()
            status = "解压完成，共 \(files.count) 个文件"
        } catch {
            status = "解压失败: \(error.localizedDescription)"
        }
        busy = false
    }

    private func doCommit() async {
        busy = true; status = "提交中…"
        do {
            try await api.sync(localDir: repo.localDir, message: "update from RepoBox") { s in
                Task { @MainActor in status = s }
            }
            status = "提交完成"
        } catch {
            status = "提交失败: \(error.localizedDescription)"
        }
        busy = false
    }
}
