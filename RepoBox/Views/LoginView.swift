import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: RepoStore
    @State private var token = ""
    @State private var busy = false
    @State private var err = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            Text("RepoBox").font(.largeTitle).bold()
            Text("粘贴 GitHub PAT 登录").foregroundColor(.secondary)

            SecureField("ghp_...", text: $token)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal)

            if busy { ProgressView() }
            if !err.isEmpty {
                Text(err).foregroundColor(.red).font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task { await login() }
            } label: {
                Text("登录").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(token.isEmpty || busy)
            .padding(.horizontal)

            Spacer()
        }
    }

    func login() async {
        busy = true; err = ""
        do {
            let name = try await GitHubClient(token: token).validate()
            Keychain.githubToken = token
            store.setUsername(name)
        } catch {
            err = "登录失败: \(error.localizedDescription)"
        }
        busy = false
    }
}