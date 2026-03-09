//
//  TiptapToolbarView.swift
//  CapsuleAI
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

enum TiptapBridge {
    static var pendingImageDataUrl: String?
}

struct TiptapContentPayload {
    let json: Data?
    let plain: String
    var editorId: UUID?
}

extension Notification.Name {
    static let tiptapCommand = Notification.Name("tiptapCommand")
    static let tiptapInjectImage = Notification.Name("tiptapInjectImage")
    static let tiptapContentRequest = Notification.Name("tiptapContentRequest")
    static let tiptapContentReady = Notification.Name("tiptapContentReady")
    static let tiptapInjectHTML = Notification.Name("tiptapInjectHTML")
    static let tiptapAIAction = Notification.Name("tiptapAIAction")
    static let tiptapRequestImageGallery = Notification.Name("tiptapRequestImageGallery")
    static let tiptapRequestImageUrl = Notification.Name("tiptapRequestImageUrl")
    static let tiptapRequestYoutubeUrl = Notification.Name("tiptapRequestYoutubeUrl")
    static let tiptapInjectImageUrl = Notification.Name("tiptapInjectImageUrl")
    static let tiptapInjectYoutubeUrl = Notification.Name("tiptapInjectYoutubeUrl")
    static let notesDidUpdate = Notification.Name("notesDidUpdate")
}

private struct ImageFileData: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: UTType.image) { data in
            ImageFileData(data: data)
        }
    }
}
