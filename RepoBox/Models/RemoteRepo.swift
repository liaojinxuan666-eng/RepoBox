import Foundation

struct RemoteRepo: Identifiable, Hashable {
    var id: Int { githubID }
    let githubID: Int
    let owner: String
    let name: String
    let defaultBranch: String
    let isPrivate: Bool
}