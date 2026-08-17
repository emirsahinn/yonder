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

        public init(
            endDate: Date,
            isPaused: Bool,
            totalDurationSeconds: Int,
            intentionNote: String? = nil,
            participantCount: Int? = nil,
            roomCode: String? = nil
        ) {
            self.endDate = endDate
            self.isPaused = isPaused
            self.totalDurationSeconds = totalDurationSeconds
            self.intentionNote = intentionNote
            self.participantCount = participantCount
            self.roomCode = roomCode
        }
    }

    public var sessionStartDate: Date

    public init(sessionStartDate: Date) {
        self.sessionStartDate = sessionStartDate
    }
}
