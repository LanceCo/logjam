import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var token: String = ""
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Discogs Account") {
                    TextField("Discogs Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Personal Access Token", text: $token)
                    Button("Save") {
                        save()
                    }
                    .disabled(username.isEmpty || token.isEmpty)
                }

                if let saveMessage {
                    Text(saveMessage).foregroundStyle(LJTheme.textSecondary)
                }

                Section {
                    Link("Generate a token on Discogs", destination: URL(string: "https://www.discogs.com/settings/developers")!)
                        .foregroundStyle(LJTheme.accent)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionString).foregroundStyle(LJTheme.textSecondary)
                    }
                    Text("© \(copyrightYear) Lance Conzett")
                        .foregroundStyle(LJTheme.textSecondary)
                    Text("Logjam is a personal project and isn't affiliated with or endorsed by Discogs.")
                        .font(.caption)
                        .foregroundStyle(LJTheme.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LJTheme.background)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var copyrightYear: String {
        String(Calendar.current.component(.year, from: .now))
    }

    private func load() {
        if let saved = try? KeychainStore.shared.readDiscogsUsername() {
            username = saved
        }
        if let saved = try? KeychainStore.shared.readDiscogsToken() {
            token = saved
        }
    }

    private func save() {
        do {
            try KeychainStore.shared.saveDiscogsUsername(username)
            try KeychainStore.shared.saveDiscogsToken(token)
            saveMessage = "Saved."
        } catch {
            saveMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
