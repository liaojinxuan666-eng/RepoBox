import SwiftUI

struct AddRepoView: View {
    @EnvironmentObject var store: RepoStore
    @Environment(\.dismiss) var dismiss

    @State private var owner = ""
    @State private var name = ""
    @State private var branch = "main"
    @State private var token = ""

    var body: some View {
        NavigationView {
            Form {
                Section("仓库") {
                    TextField("owner", text: $owner)
                        .autocapitalization(.none)
                    TextField("repo", text: $name)
                        .autocapitalization(.none)
                    TextField("分支", text: $branch)
                        .autocapitalization(.none)
                }
                Section("GitHub Token") {
                    SecureField("ghp_...", text: $token)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("添加仓库")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(owner.isEmpty || name.isEmpty || token.isEmpty)
                }
            }
        }
    }

    private func save() {
        let account = "\(owner)/\(name)"
        Keychain.save(account, token)
        store.add(Repo(owner: owner, name: name, branch: branch))
        dismiss()
    }
}