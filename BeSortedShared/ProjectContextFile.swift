//
//  ProjectContextFile.swift
//  BeSortedShared
//

import Foundation
import SwiftData

@Model
final class ProjectContextFile {
    var syncUUID: UUID = UUID()
    var fileName: String = ""
    var contentText: String = ""
    var byteSize: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    init(
        fileName: String,
        contentText: String,
        byteSize: Int,
        project: Project,
        createdAt: Date = Date()
    ) {
        self.syncUUID = UUID()
        self.fileName = fileName
        self.contentText = contentText
        self.byteSize = byteSize
        self.createdAt = createdAt
        self.updatedAt = Date()
        self.project = project
    }

    func touch() {
        updatedAt = Date()
    }
}
