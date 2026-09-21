//
//  ProjectBug.swift
//  BeSortedShared
//

import Foundation
import SwiftData

@Model
final class ProjectBug {
    var syncUUID: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var severity: Int = 3
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var relatedTaskName: String = ""

    var project: Project?

    init(
        title: String,
        details: String,
        severity: Int,
        project: Project,
        relatedTaskName: String = "",
        createdAt: Date = Date()
    ) {
        self.syncUUID = UUID()
        self.title = title
        self.details = details
        self.severity = severity
        self.createdAt = createdAt
        self.updatedAt = Date()
        self.project = project
        self.relatedTaskName = relatedTaskName
    }

    func touch() {
        updatedAt = Date()
    }
}
