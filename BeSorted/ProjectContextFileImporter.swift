//
//  ProjectContextFileImporter.swift
//  BeSorted
//

import Foundation
import PDFKit
import UniformTypeIdentifiers

enum ProjectContextFileImporter {
    static let maxCharactersPerFile = 40_000
    static let maxFilesPerProject = 12

    static var allowedContentTypes: [UTType] {
        [
            .plainText,
            .utf8PlainText,
            .text,
            .rtf,
            .pdf,
            .json,
            .data,
            .content,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType(filenameExtension: "txt") ?? .plainText,
            UTType(filenameExtension: "swift") ?? .sourceCode,
            UTType(filenameExtension: "cs") ?? .sourceCode,
            UTType(filenameExtension: "cpp") ?? .sourceCode,
            UTType(filenameExtension: "h") ?? .sourceCode,
            UTType(filenameExtension: "py") ?? .sourceCode,
            UTType(filenameExtension: "js") ?? .sourceCode,
            UTType(filenameExtension: "ts") ?? .sourceCode
        ]
    }

    static func extractText(from url: URL) throws -> (fileName: String, text: String, byteSize: Int) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = url.lastPathComponent
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        let byteSize = values.fileSize ?? 0
        let ext = url.pathExtension.lowercased()

        let raw: String
        if ext == "pdf" {
            guard let document = PDFDocument(url: url) else {
                throw ImportError.unreadable
            }
            var pages: [String] = []
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index),
                      let pageText = page.string,
                      !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                pages.append(pageText)
            }
            raw = pages.joined(separator: "\n\n")
        } else if ext == "rtf" {
            let data = try Data(contentsOf: url)
            guard let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) else {
                throw ImportError.unreadable
            }
            raw = attributed.string
        } else {
            if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
                raw = utf8
            } else if let utf16 = try? String(contentsOf: url, encoding: .utf16) {
                raw = utf16
            } else if let iso = try? String(contentsOf: url, encoding: .isoLatin1) {
                raw = iso
            } else {
                throw ImportError.unreadable
            }
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ImportError.empty
        }

        let clipped: String
        if trimmed.count > maxCharactersPerFile {
            clipped = String(trimmed.prefix(maxCharactersPerFile)) + "\n\n[…przycięto do limitu AI…]"
        } else {
            clipped = trimmed
        }

        return (fileName, clipped, byteSize)
    }

    enum ImportError: LocalizedError {
        case unreadable
        case empty
        case limitReached

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "Nie udało się odczytać tekstu z pliku."
            case .empty:
                return "Plik nie zawiera użytecznego tekstu dla AI."
            case .limitReached:
                return "Osiągnięto limit plików kontekstowych w projekcie."
            }
        }
    }
}
