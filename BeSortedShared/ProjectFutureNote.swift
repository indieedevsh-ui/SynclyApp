//
//  ProjectFutureNote.swift
//  BeSortedShared
//

import Foundation
import SwiftData

@Model
final class ProjectFutureNote {
    var syncUUID: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var project: Project?

    init(text: String, project: Project, createdAt: Date = Date()) {
        self.syncUUID = UUID()
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = Date()
        self.project = project
    }

    func touch() {
        updatedAt = Date()
    }
}
