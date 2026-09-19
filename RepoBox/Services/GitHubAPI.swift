import Foundation

// MARK: - 单个仓库操作（用全局 PAT）
struct GitHubAPI {
    let token: String
    let owner: String
    let repo: String
    let branch: String

    private func req(_ path: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest {
        var r = URLRequest(url: URL(string: "https://api.github.com\(path)")!)
        r.httpMethod = method
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("RepoBox", forHTTPHeaderField: "User-Agent")
        if let body {
            r.httpBody = try? JSONSerialization.data(withJSONObject: body)
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return r
    }

    // 下载 zipball 解压到 dir
    func clone(to dir: URL) async throws {
        var r = req("/repos/\(owner)/\(repo)/zipball/\(branch)")
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (tmp, resp) = try await URLSession.shared.download(for: r)
        try check(resp)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try ZipImporter.extract(tmp, to: dir, stripFirstComponent: true)
    }

    // 远程 tree: path -> sha
    func remoteTree() async throws -> [String: String] {
        let (data, resp) = try await URLSession.shared.data(
            for: req("/repos/\(owner)/\(repo)/git/trees/\(branch)?recursive=1"))
        try check(resp)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var out: [String: String] = [:]
        for item in json["tree"] as? [[String: Any]] ?? [] {
            if item["type"] as? String == "blob",
               let p = item["path"] as? String,
               let s = item["sha"] as? String {
                out[p] = s
            }
        }
        return out
    }

    func putFile(path: String, data: Data, sha: String?, message: String) async throws {
        var body: [String: Any] = [
            "message": message,
            "content": data.base64EncodedString(),
            "branch": branch
        ]
        if let sha { body["sha"] = sha }
        let (_, resp) = try await URLSession.shared.data(
            for: req("/repos/\(owner)/\(repo)/contents/\(encode(path))",
                     method: "PUT", body: body))
        try check(resp)
    }

    func deleteFile(path: String, sha: String, message: String) async throws {
        let body: [String: Any] = ["message": message, "sha": sha, "branch": branch]
        let (_, resp) = try await URLSession.shared.data(
            for: req("/repos/\(owner)/\(repo)/contents/\(encode(path))",
                     method: "DELETE", body: body))
        try check(resp)
    }

    // 把本地目录同步到远程
    func sync(localDir: URL, message: String,
              progress: @escaping (String) -> Void) async throws {
        let remote = try await remoteTree()

        var local: [String: Data] = [:]
        let en = FileManager.default.enumerator(at: localDir, includingPropertiesForKeys: nil)!
        for case let url as URL in en {
            if url.hasDirectoryPath { continue }
            let rel = url.path.replacingOccurrences(of: localDir.path + "/", with: "")
            if rel.hasPrefix(".git/") { continue }
            if let d = try? Data(contentsOf: url) { local[rel] = d }
        }

        for (path, data) in local {
            progress("上传 \(path)")
            try await putFile(path: path, data: data, sha: remote[path], message: message)
        }

        for (path, sha) in remote where local[path] == nil {
            progress("删除 \(path)")
            try await deleteFile(path: path, sha: sha, message: "delete \(path)")
        }
    }

    private func encode(_ path: String) -> String {
        path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
    }

    private func check(_ resp: URLResponse) throws {
        guard let h = resp as? HTTPURLResponse else { return }
        guard (200..<300).contains(h.statusCode) else {
            throw NSError(domain: "RepoBox", code: h.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(h.statusCode)"])
        }
    }
}

// MARK: - 账号级操作（登录、列仓库）
struct GitHubClient {
    let token: String

    private func req(_ path: String) -> URLRequest {
        var r = URLRequest(url: URL(string: "https://api.github.com\(path)")!)
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("RepoBox", forHTTPHeaderField: "User-Agent")
        return r
    }

    // 验证 token，返回用户名
    func validate() async throws -> String {
        let (data, resp) = try await URLSession.shared.data(for: req("/user"))
        guard let h = resp as? HTTPURLResponse, h.statusCode == 200 else {
            throw NSError(domain: "RepoBox", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "PAT 无效"])
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["login"] as? String ?? "unknown"
    }

    // 列出当前用户所有仓库
    func listRepos() async throws -> [RemoteRepo] {
        let (data, resp) = try await URLSession.shared.data(
            for: req("/user/repos?per_page=100&sort=updated"))
        guard let h = resp as? HTTPURLResponse, h.statusCode == 200 else {
            throw NSError(domain: "RepoBox", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "拉仓库失败"])
        }
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return arr.compactMap { item in
            guard let id = item["id"] as? Int,
                  let name = item["name"] as? String,
                  let owner = (item["owner"] as? [String: Any])?["login"] as? String
            else { return nil }
            return RemoteRepo(
                githubID: id,
                owner: owner,
                name: name,
                defaultBranch: item["default_branch"] as? String ?? "main",
                isPrivate: item["private"] as? Bool ?? false
            )
        }
    }
}
