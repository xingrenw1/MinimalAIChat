import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

enum ChatAttachmentKind: String, Codable {
    case image
    case pdf
    case text
    case file
}

struct ChatAttachment: Identifiable, Codable, Hashable {
    let id: UUID
    let fileName: String
    let mimeType: String
    let kind: ChatAttachmentKind
    let localFileName: String
    let sizeBytes: Int

    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        kind: ChatAttachmentKind,
        localFileName: String,
        sizeBytes: Int
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.kind = kind
        self.localFileName = localFileName
        self.sizeBytes = sizeBytes
    }

    var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}

enum ChatAttachmentError: LocalizedError {
    case fileTooLarge
    case unreadableFile
    case unsupportedImage
    case tooManyAttachments

    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "单个附件不能超过 12 MB。文本文件建议小于 2 MB。"
        case .unreadableFile:
            return "无法读取或保存所选文件。"
        case .unsupportedImage:
            return "无法处理这张图片，请换用 JPEG、PNG、WebP 或 GIF。"
        case .tooManyAttachments:
            return "一条消息最多添加 6 个附件。"
        }
    }
}

enum ChatAttachmentManager {
    static let maximumAttachmentCount = 6
    private static let maximumFileSize = 12 * 1024 * 1024

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ChatAttachments", isDirectory: true)
    }

    static func importImage(_ image: UIImage) throws -> ChatAttachment {
        let maxDimension: CGFloat = 2048
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > 0 else { throw ChatAttachmentError.unsupportedImage }
        let scale = min(1, maxDimension / maxSide)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = resized.jpegData(compressionQuality: 0.84) else {
            throw ChatAttachmentError.unsupportedImage
        }
        return try save(
            data: data,
            originalName: "图片-\(Date().timeIntervalSince1970).jpg",
            mimeType: "image/jpeg",
            kind: .image
        )
    }

    static func importFile(at url: URL) throws -> ChatAttachment {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        if let size = values?.fileSize, size > maximumFileSize {
            throw ChatAttachmentError.fileTooLarge
        }

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count <= maximumFileSize else { throw ChatAttachmentError.fileTooLarge }

        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        let mime = type?.preferredMIMEType ?? "application/octet-stream"
        let kind: ChatAttachmentKind
        if type?.conforms(to: .image) == true {
            guard let image = UIImage(data: data) else {
                throw ChatAttachmentError.unsupportedImage
            }
            return try importImage(image)
        } else if type?.conforms(to: .pdf) == true {
            kind = .pdf
        } else if type?.conforms(to: .text) == true ||
                    ["json", "csv", "md", "xml", "yaml", "yml"].contains(url.pathExtension.lowercased()) {
            kind = .text
        } else {
            kind = .file
        }

        return try save(
            data: data,
            originalName: url.lastPathComponent,
            mimeType: mime,
            kind: kind
        )
    }

    static func data(for attachment: ChatAttachment) -> Data? {
        try? Data(contentsOf: fileURL(for: attachment))
    }

    static func image(for attachment: ChatAttachment) -> UIImage? {
        guard attachment.kind == .image else { return nil }
        return UIImage(contentsOfFile: fileURL(for: attachment).path)
    }

    static func text(for attachment: ChatAttachment, maximumCharacters: Int = 200_000) -> String? {
        guard attachment.kind == .text, let data = data(for: attachment) else { return nil }
        let decoded = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
        guard let decoded else { return nil }
        return String(decoded.prefix(maximumCharacters))
    }

    static func remove(_ attachment: ChatAttachment) {
        try? FileManager.default.removeItem(at: fileURL(for: attachment))
    }

    private static func save(
        data: Data,
        originalName: String,
        mimeType: String,
        kind: ChatAttachmentKind
    ) throws -> ChatAttachment {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let id = UUID()
            let ext = URL(fileURLWithPath: originalName).pathExtension
            let storedName = id.uuidString + (ext.isEmpty ? "" : ".\(ext.lowercased())")
            try data.write(to: directory.appendingPathComponent(storedName), options: .atomic)
            return ChatAttachment(
                id: id,
                fileName: originalName,
                mimeType: mimeType,
                kind: kind,
                localFileName: storedName,
                sizeBytes: data.count
            )
        } catch let error as ChatAttachmentError {
            throw error
        } catch {
            throw ChatAttachmentError.unreadableFile
        }
    }

    private static func fileURL(for attachment: ChatAttachment) -> URL {
        directory.appendingPathComponent(attachment.localFileName)
    }
}

struct ChatAttachmentDocumentPicker: UIViewControllerRepresentable {
    let completion: (Result<[ChatAttachment], Error>) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.image, .pdf, .plainText, .json, .commaSeparatedText, .data],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: ChatAttachmentDocumentPicker

        init(parent: ChatAttachmentDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.presentationMode.wrappedValue.dismiss()
            do {
                guard urls.count <= ChatAttachmentManager.maximumAttachmentCount else {
                    throw ChatAttachmentError.tooManyAttachments
                }
                let attachments = try urls.map { try ChatAttachmentManager.importFile(at: $0) }
                parent.completion(.success(attachments))
            } catch {
                parent.completion(.failure(error))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
