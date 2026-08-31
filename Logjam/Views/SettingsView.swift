import SwiftUI

struct SettingsView: View {
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
                    Text(saveMessage).foregroundStyle(.secondary)
                }

                Section {
                    Link("Generate a token on Discogs", destination: URL(string: "https://www.discogs.com/settings/developers")!)
                        .foregroundStyle(LJTheme.accent)
                }
            }
            .scrollContentBackground(.hidden)
            .background(LJTheme.background)
            .navigationTitle("Settings")
            .onAppear(perform: load)
        }
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
