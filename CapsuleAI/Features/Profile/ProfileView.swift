//
//  ProfileView.swift
//  CapsuleAI
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ProfileViewModel()
    @State private var showAddSpace = false
    @State private var showAddTag = false
    @State private var showAddCollaborator = false
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var newSpaceName = ""
    @State private var newSpaceColor = "#3B82F6"
    @State private var newTagName = ""
    @State private var newTagColor = "#3B82F6"
    @State private var spaceToDelete: Space?
    @State private var spaceToEdit: Space?
    @State private var spacesEditMode = false
    @State private var tagToEdit: Tag?
    @State private var tagToDelete: Tag?
    @State private var collabToEdit: Profile?

    var body: some View {
        NavigationStack {
            mainContent
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Déconnexion", role: .destructive) {
                        Task { await viewModel.signOut() }
                    }
                }
            }
            .task(id: appState.currentWorkspaceId) {
                await viewModel.load(fallbackWorkspaceId: appState.currentWorkspaceId)
            }
            .refreshable {
                await viewModel.load(fallbackWorkspaceId: appState.currentWorkspaceId)
            }
            .onChange(of: viewModel.firstName) { _, _ in viewModel.scheduleAutoSave() }
            .onChange(of: viewModel.lastName) { _, _ in viewModel.scheduleAutoSave() }
            .onChange(of: viewModel.city) { _, _ in viewModel.scheduleAutoSave() }
            .onChange(of: viewModel.title) { _, _ in viewModel.scheduleAutoSave() }
            .onChange(of: viewModel.company) { _, _ in viewModel.scheduleAutoSave() }
            .onChange(of: viewModel.geolocationEnabled) { _, _ in viewModel.scheduleAutoSave() }
            .onChange(of: viewModel.notificationsEnabled) { _, enabled in
                viewModel.scheduleAutoSave()
                if enabled {
                    Task { await PushNotificationService.shared.registerIfAuthorized() }
                }
            }
            .onChange(of: viewModel.didSignOut) { _, signedOut in
                if signedOut {
                    appState.isAuthenticated = false
                    appState.currentProfile = nil
                    appState.currentWorkspaceId = nil
                    dismiss()
                }
            }
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let resized = resizeImage(data, to: CGSize(width: 200, height: 200)) {
                        await viewModel.uploadAvatar(imageData: resized)
                    }
                }
            }
            .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let msg = viewModel.errorMessage { Text(msg) }
            }
            .sheet(isPresented: $showAddSpace) { addSpaceSheet }
            .sheet(isPresented: $showAddCollaborator) { addCollaboratorSheet }
            .sheet(item: $collabToEdit) { collab in
                EditCollaboratorSheet(
                    collaborator: collab,
                    workspaceId: viewModel.profile?.workspaceId ?? appState.currentWorkspaceId,
                    spaces: viewModel.spaces,
                    subSpacesBySpace: viewModel.subSpacesBySpace,
                    onSave: {
                        Task { await viewModel.load() }
                        collabToEdit = nil
                    },
                    onDismiss: { collabToEdit = nil }
                )
            }
            .sheet(isPresented: $showAddTag) { addTagSheet }
            .sheet(item: $tagToEdit) { tag in editTagSheet(tag) }
            .sheet(item: $spaceToEdit) { space in editSpaceSheet(space) }
            .confirmationDialog("Supprimer l'espace ?", isPresented: .constant(spaceToDelete != nil)) {
                Button("Supprimer", role: .destructive) {
                    if let s = spaceToDelete { Task { try? await viewModel.deleteSpace(s) } }
                    spaceToDelete = nil
                }
                Button("Annuler", role: .cancel) { spaceToDelete = nil }
            } message: {
                Text("Un espace ne peut être supprimé que s'il n'a aucun sous-espace.")
            }
            .confirmationDialog("Supprimer le tag ?", isPresented: .constant(tagToDelete != nil)) {
                Button("Supprimer", role: .destructive) {
                    if let t = tagToDelete { Task { try? await viewModel.deleteTag(t) } }
                    tagToDelete = nil
                }
                Button("Annuler", role: .cancel) { tagToDelete = nil }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.profile == nil {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.profile != nil {
            profileContent
        } else {
            ContentUnavailableView("Profil", systemImage: "person.circle")
        }
    }

    private var profileContent: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerSection
                saveButtonSection
                personalInfoSection
                statsSection
                spacesSection
                if viewModel.isManager {
                    collaboratorsSection
                }
                tagsSection
                settingsSection
            }
            .padding(Spacing.lg)
        }
    }

    private var saveButtonSection: some View {
        Button {
            Task {
                await viewModel.save()
                if viewModel.errorMessage == nil, let p = viewModel.profile {
                    appState.currentProfile = p
                }
            }
        } label: {
            Text("Sauvegarder")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(Color.capsulePrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .disabled(viewModel.isSaving)
    }

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack(alignment: .bottomTrailing) {
                    if let urlStr = viewModel.profile?.avatarUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in image.resizable() } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                    }
                    Circle()
                        .fill(Color.capsuleSuccess)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .offset(x: -2, y: -2)
                }
            }
            .buttonStyle(.plain)

            Text("MON COMPTE")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("\(viewModel.firstName) \(viewModel.lastName)".trimmingCharacters(in: .whitespaces))
                .font(.title2)
                .fontWeight(.bold)

            if !viewModel.city.isEmpty {
                Label(viewModel.city, systemImage: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Infos personnelles")
            VStack(spacing: Spacing.sm) {
                profileField("Prénom", text: $viewModel.firstName)
                profileField("Nom", text: $viewModel.lastName)
                profileFieldReadOnly("Email", value: viewModel.profile?.email ?? "")
                profileField("Ville", text: $viewModel.city, placeholder: "ex. Marrakech · Paris")
                profileField("Titre", text: $viewModel.title, placeholder: "ex. CEO & Fondateur")
                if viewModel.isManager {
                    profileField("Entreprise", text: $viewModel.company)
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Activité Capsule")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
                statCard(icon: "note.text", value: "\(viewModel.notesTotal)", label: "Notes totales")
                statCard(icon: "folder.fill", value: "\(viewModel.spacesActive)", label: "Espaces actifs")
                statCard(icon: "pencil", value: "\(viewModel.notesCreatedByUser)", label: "Créées par \(viewModel.firstName.isEmpty ? "moi" : viewModel.firstName)")
                statCard(icon: "star.fill", value: "\(viewModel.tagsImportant)", label: "Tags importants")
            }
        }
    }

    private var spacesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Gestion des espaces")
            if viewModel.isManager {
            Button {
                newSpaceName = ""
                newSpaceColor = "#3B82F6"
                showAddSpace = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Ajouter un espace")
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.md).strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6])).foregroundStyle(.secondary))
            }
            .buttonStyle(.plain)
            }

            spacesList
        }
    }

    private var spacesList: some View {
        let nonDefault = viewModel.spaces.filter { !$0.isDefault }
        let defaultSpace = viewModel.spaces.first(where: { $0.isDefault })
        return VStack(spacing: Spacing.sm) {
            ForEach(nonDefault) { space in
                spaceRow(space)
                    .padding(Spacing.sm)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
            if let defaultSpace {
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color(hex: defaultSpace.color))
                        .frame(width: 12, height: 12)
                    Text(defaultSpace.emoji)
                    Text(defaultSpace.name)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(viewModel.subSpacesBySpace[defaultSpace.id]?.count ?? 0) sous-catégories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            }
        }
    }

    private func spaceRow(_ space: Space) -> some View {
        let subs = viewModel.subSpacesBySpace[space.id] ?? []
        return HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color(hex: space.color))
                .frame(width: 12, height: 12)
            Text(space.emoji)
            Text(space.name)
                .fontWeight(.medium)
            Spacer()
            Text("\(subs.count) sous-catégories · 0 notes")
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.isManager {
                Button {
                    spaceToEdit = space
                } label: {
                    Image(systemName: "pencil")
                }
                Button(role: .destructive) {
                    spaceToDelete = space
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var collaboratorsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                sectionTitle("Collaborateurs")
                Spacer()
                Text("\(viewModel.collaboratorCount)/\(AppLimits.maxCollaborators)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                showAddCollaborator = true
            } label: {
                Label("Ajouter", systemImage: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.md)
            }
            .buttonStyle(.bordered)

            ForEach(viewModel.collaborators) { collab in
                Button {
                    collabToEdit = collab
                } label: {
                    HStack(spacing: Spacing.md) {
                        avatarView(url: collab.avatarUrl)
                        VStack(alignment: .leading) {
                            Text(collaboratorDisplayName(collab))
                            Text(collab.title ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        statusButton(collab.status)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(Spacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Tags")
            HStack(spacing: Spacing.sm) {
                Button {
                    newTagName = ""
                    newTagColor = "#3B82F6"
                    showAddTag = true
                } label: {
                    Label("Ajouter", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.md)
                }
                .buttonStyle(.bordered)
                if viewModel.isManager {
                    Button {
                        Task { await viewModel.syncDefaultTags() }
                    } label: {
                        Label("Sync défaut", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .padding(Spacing.md)
                    }
                    .buttonStyle(.bordered)
                }
            }

            ForEach(viewModel.tags) { tag in
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color(hex: tag.color))
                        .frame(width: 12, height: 12)
                    Text(tag.name)
                    Text("#\(tag.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button { tagToEdit = tag } label: { Image(systemName: "pencil") }
                    Button(role: .destructive) { tagToDelete = tag } label: { Image(systemName: "trash") }
                }
                .padding(Spacing.sm)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Paramètres")
            Toggle("Géolocalisation", isOn: $viewModel.geolocationEnabled)
            Toggle("Notifications", isOn: $viewModel.notificationsEnabled)
            Button(role: .destructive) {
                Task { await viewModel.signOut() }
            } label: {
                Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func profileField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        TextField(placeholder.isEmpty ? label : placeholder, text: text)
            .textFieldStyle(.roundedBorder)
    }

    private func profileFieldReadOnly(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(Color.capsulePrimary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }

    private func avatarView(url: String?) -> some View {
        Group {
            if let u = url, let url = URL(string: u) {
                AsyncImage(url: url) { img in img.resizable() } placeholder: { Color.gray.opacity(0.3) }
            } else {
                Image(systemName: "person.circle.fill")
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func statusButton(_ status: String) -> some View {
        let (label, color) = statusDisplay(status)
        return Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 4)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    private func statusDisplay(_ status: String) -> (String, Color) {
        switch status {
        case "available": return ("Dispo", Color.capsuleSuccess)
        case "vacation": return ("Congés", Color.capsuleError)
        case "sick": return ("Malade", Color.orange)
        default: return ("Aucun", Color.gray)
        }
    }

    private func collaboratorDisplayName(_ collab: Profile) -> String {
        let name = "\(collab.firstName ?? "") \(collab.lastName ?? "")".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? collab.email : name
    }

    private var addCollaboratorSheet: some View {
        AddCollaboratorSheet(
            workspaceId: viewModel.profile?.workspaceId,
            onAdd: {
                Task { await viewModel.load() }
                showAddCollaborator = false
            },
            onDismiss: { showAddCollaborator = false }
        )
    }

    private var addSpaceSheet: some View {
        NavigationStack {
            Form {
                TextField("Nom du nouvel espace", text: $newSpaceName)
                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.sm) {
                        ForEach(TagColors.all, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(newSpaceColor == hex ? Color.primary : Color.clear, lineWidth: 3))
                                .onTapGesture { newSpaceColor = hex }
                        }
                    }
                }
            }
            .navigationTitle("Nouvel espace")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showAddSpace = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        Task {
                            do {
                                let name = newSpaceName.trimmingCharacters(in: .whitespaces)
                                guard !name.isEmpty else { return }
                                try await viewModel.addSpace(name: name, color: newSpaceColor, fallbackWorkspaceId: appState.currentWorkspaceId)
                                newSpaceName = ""
                                showAddSpace = false
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(newSpaceName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var addTagSheet: some View {
        NavigationStack {
            Form {
                TextField("Nom du tag", text: $newTagName)
                Section("Couleur") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Spacing.sm) {
                        ForEach(TagColors.all, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 36, height: 36)
                                .overlay(Circle().stroke(newTagColor == hex ? Color.primary : Color.clear, lineWidth: 3))
                                .onTapGesture { newTagColor = hex }
                        }
                    }
                }
            }
            .navigationTitle("Nouveau tag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showAddTag = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            do {
                                try await viewModel.addTag(name: newTagName, color: newTagColor)
                                showAddTag = false
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func editSpaceSheet(_ space: Space) -> some View {
        EditSpaceSheet(space: space, onSave: { newName, newColor in
            Task {
                try? await viewModel.updateSpaceName(space, name: newName)
                try? await viewModel.updateSpaceColor(space, color: newColor)
                spaceToEdit = nil
            }
        }, onDismiss: { spaceToEdit = nil })
    }

    private func editTagSheet(_ tag: Tag) -> some View {
        TagEditSheet(tag: tag, onSave: { name, color in
            Task { try? await viewModel.updateTag(tag, name: name, color: color) }
            tagToEdit = nil
        }, onDismiss: { tagToEdit = nil })
    }

    private func resizeImage(_ data: Data, to size: CGSize) -> Data? {
        guard let ui = UIImage(data: data) else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { _ in ui.draw(in: CGRect(origin: .zero, size: size)) }
        return img.jpegData(compressionQuality: 0.8)
    }
}
