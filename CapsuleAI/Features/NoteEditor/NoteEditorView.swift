//
//  NoteEditorView.swift
//  CapsuleAI
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

enum NoteEditorMode {
    case create(subSpaceId: UUID?, spaceId: UUID?)
    case edit(noteId: UUID)
    case editWithContent(noteId: UUID, htmlContent: String)
}

struct NoteEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let mode: NoteEditorMode
    var onSaveSuccess: (() -> Void)?
    var onBack: (() -> Void)?
    @State private var viewModel = NoteEditorViewModel()
    @State private var isSaving = false
    @State private var showDiscardConfirm = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var editorId = UUID()
    @State private var aiTriggerAction: AIAction?
    @State private var showBridgeImagePicker = false
    @State private var bridgeImagePickerItems: [PhotosPickerItem] = []
    @State private var showImageUrlSheet = false
    @State private var showYoutubeUrlSheet = false
    @State private var imageUrlInput = ""
    @State private var youtubeUrlInput = ""
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var createdNoteId: UUID?

    private var hasUnsavedChanges: Bool {
        !viewModel.title.trimmingCharacters(in: .whitespaces).isEmpty
        || !viewModel.contentPlain.isEmpty
        || (viewModel.contentJson != nil && (viewModel.contentJson?.count ?? 0) > 20)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    SpacePickerView(
                        spaces: viewModel.spaces,
                        subSpaces: viewModel.subSpaces,
                        selectedSpaceId: $viewModel.selectedSpaceId,
                        selectedSubSpaceId: $viewModel.selectedSubSpaceId
                    )
                    titleField
                }
                .padding(Spacing.md)
            }
            .frame(maxHeight: 220)

            tiptapSection
                .padding(.horizontal, Spacing.md)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    tagsSection
                    noteTypeSection
                    actionPlanSection
                    attachmentsSection
                    geolocationSection
                    Toggle("Note privée (visible uniquement par moi)", isOn: $viewModel.isPrivate)
                    Toggle("Épinglée", isOn: $viewModel.isPinned)
                }
                .padding(Spacing.md)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Retour") {
                    if hasUnsavedChanges {
                        showDiscardConfirm = true
                    } else {
                        performBack()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") { Task { await performSave(dismissOnSuccess: true) } }
                    .disabled(!viewModel.canSave || isSaving)
            }
        }
        .task {
            guard let wsId = appState.currentWorkspaceId else { return }
            await viewModel.load(workspaceId: wsId)
            if case .create(let subId, let spaceId) = mode {
                if let sid = spaceId, let subid = subId {
                    viewModel.selectedSpaceId = sid
                    viewModel.selectedSubSpaceId = subid
                } else {
                    // Auto-sélection : premier sous-espace non-poubelle pour créer immédiatement
                    viewModel.selectDefaultSpaceAndSubSpace()
                }
            } else if case .edit(let noteId) = mode {
                await viewModel.loadNote(noteId: noteId)
            } else if case .editWithContent(let noteId, let html) = mode {
                viewModel.initialHtmlOverride = html
                await viewModel.loadNote(noteId: noteId)
            }
            startAutoSaveTimer()
        }
        .onDisappear {
            autoSaveTask?.cancel()
        }
        .alert("Erreur", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .confirmationDialog("Modifications non enregistrées", isPresented: $showDiscardConfirm) {
            Button("Quitter", role: .destructive) {
                performBack()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Des modifications n'ont pas été enregistrées. Voulez-vous vraiment quitter ?")
        }
        .onChange(of: appState.selectedTabIndex) { _, newIndex in
            // Onglet création = 2. Quand on revient après avoir sauvegardé, réinitialiser pour une nouvelle note.
            if case .create = mode, newIndex == 2, createdNoteId != nil {
                createdNoteId = nil
                viewModel.resetForNewNote()
                editorId = UUID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tiptapAIAction)) { notif in
            if let action = notif.object as? String, let a = AIAction(rawValue: action) {
                aiTriggerAction = a
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tiptapRequestImageGallery)) { _ in
            showBridgeImagePicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .tiptapRequestImageUrl)) { _ in
            imageUrlInput = "https://"
            showImageUrlSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .tiptapRequestYoutubeUrl)) { _ in
            youtubeUrlInput = "https://www.youtube.com/watch?v="
            showYoutubeUrlSheet = true
        }
        .sheet(isPresented: $showBridgeImagePicker) { bridgeImagePickerSheet }
        .sheet(isPresented: $showImageUrlSheet) {
            urlInputSheet(
                title: "URL de l'image",
                placeholder: "https://exemple.com/image.jpg",
                text: $imageUrlInput,
                onInsert: {
                    let url = imageUrlInput.trimmingCharacters(in: .whitespaces)
                    if !url.isEmpty {
                        NotificationCenter.default.post(name: .tiptapInjectImageUrl, object: url)
                    }
                    showImageUrlSheet = false
                    imageUrlInput = ""
                },
                onCancel: { showImageUrlSheet = false; imageUrlInput = "" }
            )
        }
        .sheet(isPresented: $showYoutubeUrlSheet) {
            urlInputSheet(
                title: "URL YouTube",
                placeholder: "https://www.youtube.com/watch?v=...",
                text: $youtubeUrlInput,
                onInsert: {
                    let url = youtubeUrlInput.trimmingCharacters(in: .whitespaces)
                    if !url.isEmpty {
                        NotificationCenter.default.post(name: .tiptapInjectYoutubeUrl, object: url)
                    }
                    showYoutubeUrlSheet = false
                    youtubeUrlInput = ""
                },
                onCancel: { showYoutubeUrlSheet = false; youtubeUrlInput = "" }
            )
        }
        .onChange(of: bridgeImagePickerItems) { _, items in
            guard let item = items.first else { return }
            Task {
                await injectImageFromPicker(item)
                await MainActor.run {
                    bridgeImagePickerItems = []
                    showBridgeImagePicker = false
                }
            }
        }
    }

    private func performBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }

    private var geolocationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Géolocalisation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let loc = viewModel.locationDisplay {
                    Text(loc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await viewModel.fetchLocation() }
                } label: {
                    Label(viewModel.locationDisplay != nil ? "Mettre à jour" : "Géolocaliser", systemImage: "location")
                }
            }
        }
    }

    private var titleField: some View {
        TextField("Titre de la note...", text: $viewModel.title)
            .textInputAutocapitalization(.sentences)
            .font(.headline)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Tags (\(viewModel.selectedTagIds.count)/\(AppLimits.maxTagsPerNote))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if viewModel.tags.isEmpty {
                Text("Aucun tag. Créez-en dans Profil > Tags.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                TagPickerView(tags: viewModel.tags, selectedTagIds: $viewModel.selectedTagIds)
            }
        }
    }

    @ViewBuilder
    private var noteTypeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Type de note")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: Spacing.sm) {
                ForEach(viewModel.noteTypes) { type in
                    let isSelected = viewModel.selectedNoteTypeId == type.id
                    Button {
                        viewModel.selectedNoteTypeId = isSelected ? nil : type.id
                        if viewModel.selectedNoteTypeId != nil {
                            Task { await viewModel.loadActionsForSelectedType() }
                        } else {
                            viewModel.actionCheckboxes = []
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(type.emoji)
                            Text(type.name)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(isSelected ? Color.capsulePrimary.opacity(0.3) : Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var actionPlanSection: some View {
        if !viewModel.actionCheckboxes.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Plan d'action")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(viewModel.actionCheckboxes) { item in
                        Button {
                            viewModel.toggleAction(id: item.id)
                        } label: {
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(item.isChecked ? Color.capsuleSuccess : .secondary)
                                Text(item.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .strikethrough(item.isChecked)
                                Spacer()
                            }
                            .padding(Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(item.isChecked ? Color.capsuleSuccess.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Pièces jointes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Label("Photo", systemImage: "photo")
                }
                .onChange(of: selectedPhotoItems) { _, items in
                    Task { await viewModel.processSelectedPhotos(items: items) }
                }
                Button {
                    viewModel.showDocumentPicker = true
                } label: {
                    Label("PDF / Doc", systemImage: "doc")
                }
            }
            if !viewModel.pendingAttachments.isEmpty {
                ForEach(viewModel.pendingAttachments) { att in
                    HStack {
                        Image(systemName: att.isPhoto ? "photo" : "doc.fill")
                        Text(att.fileName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.removePendingAttachment(att.id)
                        } label: { Image(systemName: "xmark.circle.fill") }
                    }
                    .padding(Spacing.xs)
                }
            }
        }
        .sheet(isPresented: $viewModel.showDocumentPicker) {
            DocumentPickerView(types: [UTType.pdf, UTType.plainText, UTType.compositeContent]) { url in
                viewModel.addDocument(url: url)
                viewModel.showDocumentPicker = false
            }
        }
    }

    @ViewBuilder
    private func urlInputSheet(title: String, placeholder: String, text: Binding<String>, onInsert: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insérer", action: onInsert)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var bridgeImagePickerSheet: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Text("Choisir une photo")
                    .font(.headline)
                PhotosPicker(
                    selection: $bridgeImagePickerItems,
                    maxSelectionCount: 1,
                    matching: .images
                ) {
                    Label("Ouvrir la galerie", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "#3B82F6").opacity(0.2))
                        .foregroundStyle(Color(hex: "#3B82F6"))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
                Spacer()
            }
            .padding(Spacing.lg)
            .navigationTitle("Ajouter une image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showBridgeImagePicker = false }
                }
            }
        }
    }

    private var tiptapSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TiptapWebView(
                contentJson: $viewModel.contentJson,
                contentPlain: $viewModel.contentPlain,
                initialHtml: viewModel.initialHtmlOverride,
                editorId: editorId
            ) { json, plain in
                viewModel.contentJson = json
                viewModel.contentPlain = plain
            }
            .id(editorId)
            .frame(minHeight: 300)
            NoteEditorAIAssistBar(
                contentPlain: viewModel.contentPlain,
                title: viewModel.title,
                isEditing: true,
                triggerAction: $aiTriggerAction,
                onInsertSummary: { html in
                    injectHtml(html)
                    let noteId: UUID? = {
                        switch mode {
                        case .edit(let nid), .editWithContent(let nid, _): return nid
                        case .create: return createdNoteId
                        }
                    }()
                    if let nid = noteId, let plain = stripHTML(html), !plain.isEmpty {
                        Task { try? await viewModel.updateAiSummary(noteId: nid, summary: plain) }
                    }
                },
                onReplaceWithStructured: { replaceWithHtml($0) },
                onInsertGenerated: { replaceWithHtml($0) }
            )
        }
    }

    private func startAutoSaveTimer() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard hasUnsavedChanges, viewModel.canSave, !isSaving else { return }
                    Task { await performSave(dismissOnSuccess: false) }
                }
            }
        }
    }

    private func performSave(dismissOnSuccess: Bool) async {
        guard let subId = viewModel.selectedSubSpaceId,
              let uid = appState.currentUserId,
              let wsId = appState.currentWorkspaceId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            try? await Task.sleep(nanoseconds: 100_000_000)

            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                final class Holder: @unchecked Sendable {
                    var token: (any NSObjectProtocol)?
                    var didResume = false
                    var cont: CheckedContinuation<Void, Never>?
                }
                let holder = Holder()
                holder.cont = cont
                holder.token = NotificationCenter.default.addObserver(forName: .tiptapContentReady, object: nil, queue: .main) { notif in
                    guard !holder.didResume else { return }
                    guard let payload = notif.object as? TiptapContentPayload else { return }
                    guard payload.editorId == editorId else { return }
                    holder.didResume = true
                    viewModel.contentJson = payload.json
                    viewModel.contentPlain = payload.plain
                    if let t = holder.token {
                        NotificationCenter.default.removeObserver(t)
                    }
                    holder.cont?.resume()
                }
                NotificationCenter.default.post(name: .tiptapContentRequest, object: editorId)
                Task { @MainActor in
                    _ = try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !holder.didResume else { return }
                    holder.didResume = true
                    if let t = holder.token {
                        NotificationCenter.default.removeObserver(t)
                    }
                    holder.cont?.resume()
                }
            }
            let noteId: UUID? = createdNoteId ?? {
                switch mode {
                case .edit(let nid), .editWithContent(let nid, _): return nid
                case .create: return nil
                }
            }()
            let savedNoteId = try await viewModel.save(workspaceId: wsId, userId: uid, noteId: noteId, subSpaceId: subId)
            if noteId == nil { createdNoteId = savedNoteId }
            let contentForSummary: String = {
                let plain = viewModel.contentPlain.trimmingCharacters(in: .whitespacesAndNewlines)
                if !plain.isEmpty { return plain }
                if let data = viewModel.contentJson, let json = JSONValue.from(data: data) {
                    let extracted = json.tiptapPlainText
                    if !extracted.isEmpty { return extracted }
                }
                return plain
            }()
            GenerateSummaryService.triggerForNote(
                id: savedNoteId,
                title: viewModel.title,
                contentPlain: contentForSummary
            )
            NotificationCenter.default.post(name: .notesDidUpdate, object: nil)
            if dismissOnSuccess {
                if let onSaveSuccess {
                    onSaveSuccess()
                } else {
                    dismiss()
                }
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func stripHTML(_ html: String) -> String? {
        guard let data = html.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func injectHtml(_ html: String) {
        viewModel.initialHtmlOverride = nil
        NotificationCenter.default.post(name: .tiptapInjectHTML, object: html)
    }

    private func replaceWithHtml(_ html: String) {
        let b64 = Data(html.utf8).base64EncodedString()
        NotificationCenter.default.post(name: .tiptapCommand, object: ("setContentHTMLFromBase64", b64))
    }

    private func injectImageFromPicker(_ item: PhotosPickerItem) async {
        struct ImageData: Transferable {
            let data: Data
            static var transferRepresentation: some TransferRepresentation {
                DataRepresentation(importedContentType: UTType.image) { ImageData(data: $0) }
            }
        }
        guard let data = try? await item.loadTransferable(type: ImageData.self)?.data else { return }
        let toUse = resizeImageForTiptap(data, maxBytes: 300 * 1024) ?? data
        let isJpeg = toUse.count >= 2 && toUse.prefix(2) == Data([0xFF, 0xD8])
        let mime = isJpeg ? "image/jpeg" : "image/png"
        let base64 = toUse.base64EncodedString()
        let dataUrl = "data:\(mime);base64,\(base64)"
        await MainActor.run {
            TiptapBridge.pendingImageDataUrl = dataUrl
            NotificationCenter.default.post(name: .tiptapInjectImage, object: nil)
        }
    }

    /// Accepte toute photo iPhone et la convertit à la volée en JPEG ≤ 300 Ko max
    private func resizeImageForTiptap(_ data: Data, maxBytes: Int) -> Data? {
        guard let ui = UIImage(data: data) else { return nil }
        let maxDim: CGFloat = 1920
        var size = ui.size
        if size.width > maxDim || size.height > maxDim {
            let ratio = min(maxDim / size.width, maxDim / size.height)
            size = CGSize(width: size.width * ratio, height: size.height * ratio)
        }
        var quality: CGFloat = 0.9
        while true {
            let renderer = UIGraphicsImageRenderer(size: size)
            let img = renderer.image { _ in ui.draw(in: CGRect(origin: .zero, size: size)) }
            guard let result = img.jpegData(compressionQuality: quality) else { return nil }
            if result.count <= maxBytes { return result }
            if quality > 0.35 {
                quality -= 0.08
            } else if size.width > 320 || size.height > 320 {
                size = CGSize(width: size.width * 0.7, height: size.height * 0.7)
                quality = 0.8
            } else {
                return result
            }
        }
    }
}

private extension NoteEditorMode {
    var title: String {
        switch self {
        case .create: return "Nouvelle note"
        case .edit: return "Modifier la note"
        case .editWithContent: return "Modifier la note"
        }
    }
}
