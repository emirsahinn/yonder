//
//  Subject.swift
//  Yonder
//

import Foundation
import SwiftData

/// SwiftData model representing a previously used focus subject / topic name.
@Model
final class Subject {
    var id: UUID
    var name: String
    var lastUsedDate: Date
    /// Tracks the last mutation time; optional so existing SwiftData stores can migrate safely.
    var updatedAt: Date?
    /// When set, the work area is hidden from new-session pickers but preserved for history.
    var archivedAt: Date?

    var isArchived: Bool {
        archivedAt != nil
    }

    init(
        id: UUID = UUID(),
        name: String,
        lastUsedDate: Date = Date(),
        updatedAt: Date? = Date(),
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.lastUsedDate = lastUsedDate
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }
}
