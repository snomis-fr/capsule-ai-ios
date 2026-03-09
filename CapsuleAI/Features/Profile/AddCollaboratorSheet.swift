//
//  AddCollaboratorSheet.swift
//  CapsuleAI
//

import SwiftUI
import Supabase

struct AddCollaboratorSheet: View {
    let workspaceId: UUID?
    let onAdd: () -> Void
    let onDismiss: () -> Void

    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var title = ""
    @State private var city = ""
    @State private var status = "none"
    @State private var selectedSubSpaceId: UUID?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var availableSubSpaces: [(Space, [SubSpace])] = []

    private let supabase = SupabaseManager.shared.client

    private let statusOptions: [(String, String)] = [
        ("none", "Aucun"),
        ("available", "Disponible"),
        ("vacation", "Congés"),
        ("sick", "Malade"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Informations principales") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Prénom", text: $firstName)
                    TextField("Nom", text: $lastName)
                }

                Section("Détails") {
                    TextField("Titre", text: $title, prompt: Text("ex. Chef de projet"))
                    TextField("Ville", text: $city, prompt: Text("ex. Paris"))
                    Picker("Statut", selection: $status) {
                        ForEach(statusOptions, id: \.0) { opt in
                            Text(opt.1).tag(opt.0)
                        }
                    }
                }

                Section("Sous-espace d'affectation") {
                    Picker("Sous-espace", selection: $selectedSubSpaceId) {
                        Text("Sélectionner…").tag(nil as UUID?)
                        ForEach(availableSubSpaces.flatMap { space, subs in
                            subs.map { sub in
                                (space, sub)
                            }
                        }, id: \.1.id) { space, sub in
                            Text("\(space.emoji) \(space.name) / \(sub.emoji) \(sub.name)")
                                .tag(sub.id as UUID?)
                        }
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(Color.capsuleError)
                    }
                }

                Section {
                    Text("Le manager crée le collaborateur directement. Aucune connexion préalable nécessaire.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajouter un collaborateur")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        Task { await createCollaborator() }
                    }
                    .disabled(!canCreate || isLoading)
                }
            }
            .task {
                await loadSubSpaces()
            }
        }
    }

    private var canCreate: Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        return !trimmedEmail.isEmpty && selectedSubSpaceId != nil
    }

    private func loadSubSpaces() async {
        guard let wsId = workspaceId else { return }
        do {
            let fetched: [Space] = try await supabase
                .from(Tables.spaces)
                .select()
                .eq("workspace_id", value: wsId)
                .order("sort_order")
                .execute()
                .value
            let spaces = fetched.sortedWithDefaultLast()

            var result: [(Space, [SubSpace])] = []
            for space in spaces {
                let subs: [SubSpace] = try await supabase
                    .from(Tables.subSpaces)
                    .select()
                    .eq("space_id", value: space.id)
                    .order("sort_order")
                    .execute()
                    .value
                result.append((space, subs))
            }
            availableSubSpaces = result
            if selectedSubSpaceId == nil, let first = result.flatMap(\.1).first {
                selectedSubSpaceId = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createCollaborator() async {
        guard let wsId = workspaceId, let subSpaceId = selectedSubSpaceId else {
            errorMessage = "Espace de travail ou sous-espace non trouvé"
            return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmedEmail.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await supabase.auth.refreshSession()
            let session = try await supabase.auth.session
            var body: [String: String] = [
                "email": trimmedEmail,
                "workspace_id": wsId.uuidString,
                "sub_space_id": subSpaceId.uuidString,
            ]
            if !firstName.isEmpty { body["first_name"] = firstName }
            if !lastName.isEmpty { body["last_name"] = lastName }
            if !title.isEmpty { body["title"] = title }
            if !city.isEmpty { body["city"] = city }
            body["status"] = status

            let bodyData = try JSONEncoder().encode(body)

            var request = URLRequest(url: URL(string: "\(SupabaseConstants.url)/functions/v1/invite-collaborator")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(SupabaseConstants.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Réponse invalide"
                return
            }

            struct InviteResponse: Decodable {
                let success: Bool?
                let error: String?
                let message: String?
            }
            let decoded = try? JSONDecoder().decode(InviteResponse.self, from: data)

            if httpResponse.statusCode == 401 {
                errorMessage = decoded?.error ?? "Session expirée. Déconnectez-vous et reconnectez-vous."
                return
            }
            if httpResponse.statusCode != 200 {
                errorMessage = decoded?.error ?? "Erreur \(httpResponse.statusCode)"
                return
            }
            if let err = decoded?.error {
                errorMessage = err
                return
            }

            onAdd()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
