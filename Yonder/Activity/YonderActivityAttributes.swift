//
//  YonderActivityAttributes.swift
//  Yonder
//

import Foundation
import ActivityKit

/// Shared ActivityKit attributes and content state for Yonder's Live Activity & Dynamic Island widget.
public struct YonderActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var endDate: Date
        public var isPaused: Bool
        public var totalDurationSeconds: Int
        public var intentionNote: String?
        public var participantCount: Int?
        public var roomCode: String?
        /// Open-ended count-up session (solo stopwatch) vs. a count-down toward `endDate`.
        public var isStopwatchMode: Bool

        public init(
            endDate: Date,
            isPaused: Bool,
            totalDurationSeconds: Int,
            intentionNote: String? = nil,
            participantCount: Int? = nil,
            roomCode: String? = nil,
            isStopwatchMode: Bool = false
        ) {
            self.endDate = endDate
            self.isPaused = isPaused
            self.totalDurationSeconds = totalDurationSeconds
            self.intentionNote = intentionNote
            self.participantCount = participantCount
            self.roomCode = roomCode
            self.isStopwatchMode = isStopwatchMode
        }
    }

    public var sessionStartDate: Date

    public init(sessionStartDate: Date) {
        self.sessionStartDate = sessionStartDate
    }
}
