import Foundation
import ZIPFoundation

enum ZipImporter {
    static func extract(_ zip: URL, to dir: URL, stripFirstComponent: Bool) throws {
        guard let archive = Archive(url: zip, accessMode: .read) else {
            throw NSError(domain: "RepoBox", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "打不开 zip"])
        }

        // 判断是否所有条目都在同一个根目录下
        let paths = archive.map { $0.path }
        var root: String? = nil
        if stripFirstComponent, let first = paths.first {
            let comp = String(first.split(separator: "/").first ?? "")
            if !comp.isEmpty && paths.allSatisfy({ $0.hasPrefix(comp + "/") }) {
                root = comp + "/"
            }
        }

        for entry in archive {
            var rel = entry.path
            if let root, rel.hasPrefix(root) {
                rel = String(rel.dropFirst(root.count))
            }
            guard !rel.isEmpty else { continue }

            let dst = dir.appendingPathComponent(rel)
            // 防路径穿越
            guard dst.standardized.path.hasPrefix(dir.standardized.path) else { continue }
            try FileManager.default.createDirectory(
                at: dst.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            _ = try archive.extract(entry, to: dst)
        }
    }
}