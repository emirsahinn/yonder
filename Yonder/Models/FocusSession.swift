//
//  FocusSession.swift
//  Yonder
//

import Foundation
import SwiftData

enum FocusSessionMode: String {
    case solo
    case room
}

/// SwiftData model representing a recorded focus session.
@Model
final class FocusSession {
    var id: UUID
    var date: Date
    var durationSeconds: Int
    var completed: Bool
    var intentionNote: String?
    var subject: String?
    var startedAt: Date?
    var endedAt: Date?
    var plannedDurationSeconds: Int?
    var modeRawValue: String = FocusSessionMode.solo.rawValue
    var roomId: String?

    var mode: FocusSessionMode {
        get { FocusSessionMode(rawValue: modeRawValue) ?? .solo }
        set { modeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date? = nil,
        durationSeconds: Int,
        completed: Bool,
        intentionNote: String? = nil,
        subject: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        plannedDurationSeconds: Int? = nil,
        modeRawValue: String = FocusSessionMode.solo.rawValue,
        roomId: String? = nil
    ) {
        self.id = id
        self.date = date ?? startedAt ?? Date()
        self.durationSeconds = durationSeconds
        self.completed = completed
        self.intentionNote = intentionNote
        self.subject = subject ?? intentionNote
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedDurationSeconds = plannedDurationSeconds
        self.modeRawValue = modeRawValue
        self.roomId = roomId
    }
}
