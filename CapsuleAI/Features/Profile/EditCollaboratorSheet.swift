//
//  EditCollaboratorSheet.swift
//  CapsuleAI
//

import SwiftUI
import Supabase
import PhotosUI

struct EditCollaboratorSheet: View {
    let collaborator: Profile
    let workspaceId: UUID?
    let spaces: [Space]
    let subSpacesBySpace: [UUID: [SubSpace]]
    let onSave: () -> Void
    let onDismiss: () -> Void

    @State private var firstName: String
    @State private var lastName: String
    @State private var title: String
    @State private var city: String
    @State private var status: String
    @State private var subSpaceAccess: Set<UUID> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarData: Data?

    private let supabase = SupabaseManager.shared.client

    private let statusOptions: [(String, String, Color)] = [
        ("available", "Dispo", Color.capsuleSuccess),
        ("vacation", "Congés", Color.capsuleError),
        ("sick", "Malade", Color.orange),
        ("none", "Aucun", Color.gray),
    ]

    init(
        collaborator: Profile,
        workspaceId: UUID?,
        spaces: [Space],
        subSpacesBySpace: [UUID: [SubSpace]],
        onSave: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.collaborator = collaborator
        self.workspaceId = workspaceId
        self.spaces = spaces
        self.subSpacesBySpace = subSpacesBySpace
        self.onSave = onSave
        self.onDismiss = onDismiss
        _firstName = State(initialValue: collaborator.firstName ?? "")
        _lastName = State(initialValue: collaborator.lastName ?? "")
        _title = State(initialValue: collaborator.title ?? "")
        _city = State(initialValue: collaborator.city ?? "")
        _status = State(initialValue: collaborator.status)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    collaboratorAvatarSection
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section("Informations principales") {
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(collaborator.email)
                            .foregroundStyle(.secondary)
                    }
                    TextField("Prénom", text: $firstName)
                    TextField("Nom", text: $lastName)
                }

                Section("Détails") {
                    TextField("Titre", text: $title, prompt: Text("ex. Chef de projet"))
                    TextField("Ville", text: $city, prompt: Text("ex. Paris"))
                }

                Section("Statut") {
                    HStack(spacing: Spacing.sm) {
                        ForEach(statusOptions, id: \.0) { opt in
                            statusButton(value: opt.0, label: opt.1, color: opt.2)
                        }
                    }
                }

                if !spaces.isEmpty, let wsId = workspaceId {
                    Section {
                        accessRightsSection(workspaceId: wsId)
                    } header: {
                        Text("Droits d'accès")
                    } footer: {
                        Text("Cochez les espaces et sous-espaces auxquels ce collaborateur peut accéder.")
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(Color.capsuleError)
                    }
                }
            }
            .navigationTitle("Fiche collaborateur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task { await saveCollaborator() }
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await loadAccessRights()
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let resized = resizeImage(data, to: CGSize(width: 200, height: 200)) {
                        pendingAvatarData = resized
                    }
                }
            }
        }
    }

    private var collaboratorAvatarSection: some View {
        HStack {
            Spacer()
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Group {
                    if let data = pendingAvatarData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                    } else {
                        CollaboratorAvatarView(collaboratorId: collaborator.id, supabase: supabase)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.vertical, Spacing.md)
    }

    private func resizeImage(_ data: Data, to size: CGSize) -> Data? {
        guard let ui = UIImage(data: data) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in ui.draw(in: CGRect(origin: .zero, size: size)) }
        return img.jpegData(compressionQuality: 0.8)
    }

    private func statusButton(value: String, label: String, color: Color) -> some View {
        Button {
            status = value
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(status == value ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(status == value ? color : color.opacity(0.2))
                .foregroundStyle(status == value ? .white : color)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func accessRightsSection(workspaceId: UUID) -> some View {
        ForEach(orderedSpaces) { space in
            let subs = subSpacesBySpace[space.id] ?? []
            let allSelected = !subs.isEmpty && subs.allSatisfy { subSpaceAccess.contains($0.id) }
            DisclosureGroup {
                ForEach(subs) { sub in
                    Toggle(isOn: bindingForSubSpace(sub.id)) {
                        HStack(spacing: Spacing.sm) {
                            Text(sub.emoji)
                            Text(sub.name)
                                .font(.subheadline)
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(space.emoji)
                    Text(space.name)
                        .fontWeight(.medium)
                    Spacer()
                    if !subs.isEmpty {
                        Button {
                            if allSelected {
                                for sub in subs { subSpaceAccess.remove(sub.id) }
                            } else {
                                for sub in subs { subSpaceAccess.insert(sub.id) }
                            }
                        } label: {
                            Text(allSelected ? "Tout décocher" : "Tout cocher")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                        Text("\(subs.filter { subSpaceAccess.contains($0.id) }.count)/\(subs.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var orderedSpaces: [Space] {
        spaces.sortedWithDefaultLast()
    }

    private func bindingForSubSpace(_ subSpaceId: UUID) -> Binding<Bool> {
        Binding(
            get: { subSpaceAccess.contains(subSpaceId) },
            set: { hasAccess in
                if hasAccess {
                    subSpaceAccess.insert(subSpaceId)
                } else {
                    subSpaceAccess.remove(subSpaceId)
                }
            }
        )
    }

    private func loadAccessRights() async {
        guard let wsId = workspaceId else { return }
        do {
            struct CARow: Decodable {
                let sub_space_id: UUID
            }
            let rows: [CARow] = try await supabase
                .from(Tables.collaboratorAccess)
                .select("sub_space_id")
                .eq("workspace_id", value: wsId)
                .eq("user_id", value: collaborator.id)
                .execute()
                .value
            subSpaceAccess = Set(rows.map(\.sub_space_id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveCollaborator() async {
        guard let wsId = workspaceId else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await supabase.auth.refreshSession()
            let session = try await supabase.auth.session
            try await saveViaAPI(session: session, workspaceId: wsId)
            onSave()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveViaAPI(session: Auth.Session, workspaceId: UUID) async throws {
        struct UpdateBody: Encodable {
            let user_id: String
            let workspace_id: String
            let first_name: String?
            let last_name: String?
            let title: String?
            let city: String?
            let status: String
            let avatar_base64: String?
            let sub_space_ids: [String]?
        }
        let body = UpdateBody(
            user_id: collaborator.id.uuidString,
            workspace_id: workspaceId.uuidString,
            first_name: firstName.isEmpty ? nil : firstName,
            last_name: lastName.isEmpty ? nil : lastName,
            title: title.isEmpty ? nil : title,
            city: city.isEmpty ? nil : city,
            status: status,
            avatar_base64: pendingAvatarData.map { $0.base64EncodedString() },
            sub_space_ids: Array(subSpaceAccess).map { $0.uuidString }
        )
        let bodyData = try JSONEncoder().encode(body)

        var request = URLRequest(url: URL(string: "\(SupabaseConstants.url)/functions/v1/update-collaborator")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConstants.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "EditCollaborator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Réponse invalide"])
        }

        struct UpdateResponse: Decodable {
            let success: Bool?
            let error: String?
        }
        let decoded = try? JSONDecoder().decode(UpdateResponse.self, from: data)

        if httpResponse.statusCode == 401 {
            throw NSError(domain: "EditCollaborator", code: 401, userInfo: [NSLocalizedDescriptionKey: decoded?.error ?? "Session expirée. Déconnectez-vous et reconnectez-vous."])
        }
        if httpResponse.statusCode != 200 {
            throw NSError(domain: "EditCollaborator", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: decoded?.error ?? "Erreur \(httpResponse.statusCode)"])
        }
        if let err = decoded?.error {
            throw NSError(domain: "EditCollaborator", code: -1, userInfo: [NSLocalizedDescriptionKey: err])
        }
    }
}

// MARK: - CollaboratorAvatarView
private struct CollaboratorAvatarView: View {
    let collaboratorId: UUID
    let supabase: Supabase.SupabaseClient

    @State private var imageURL: URL?

    var body: some View {
        Group {
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            let path = "\(collaboratorId.uuidString.lowercased())/avatar.jpg"
            do {
                let signed = try await supabase.storage
                    .from(Buckets.avatars)
                    .createSignedURL(path: path, expiresIn: 3600)
                imageURL = signed
            } catch {
                imageURL = nil
            }
        }
    }
}
