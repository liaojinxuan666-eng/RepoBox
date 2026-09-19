import Foundation

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

    // 下载 zipball 到 dir
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

    // 把本地目录同步到远程（按 path 全量对比）
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

        // 新增 / 修改
        for (path, data) in local {
            progress("上传 \(path)")
            try await putFile(path: path, data: data, sha: remote[path], message: message)
        }

        // 删除
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