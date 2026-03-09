//
//  Attachment.swift
//  CapsuleAI
//

import Foundation

struct Attachment: Codable, Identifiable {
    let id: UUID
    let noteId: UUID
    let fileName: String
    let fileType: String
    let fileSize: Int
    let storagePath: String
    let mimeType: String?
    let uploadedBy: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case noteId = "note_id"
        case fileName = "file_name"
        case fileType = "file_type"
        case fileSize = "file_size"
        case storagePath = "storage_path"
        case mimeType = "mime_type"
        case uploadedBy = "uploaded_by"
    }

    var fileTypeLabel: String {
        switch fileType {
        case "photo": return "Photo"
        case "pdf": return "PDF"
        default: return "Fichier"
        }
    }
}
