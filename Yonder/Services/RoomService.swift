//
//  RoomService.swift
//  Yonder
//
//  Data models and service for shared Focus Rooms.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Data structure representing a shared Focus Room in Firestore.
struct RoomModel: Identifiable, Equatable {
    let id: String
    let hostId: String
    let endTimestamp: Date?
    let duration: Int
    let status: String // "waiting" | "running" | "ended"
    let subject: String?
    let createdAt: Date
    let endedAt: Date?

    var isWaiting: Bool { status == "waiting" }
    var isRunning: Bool { status == "running" }
}

/// Data structure representing a Room Participant in Firestore.
struct ParticipantModel: Identifiable, Equatable {
    let id: String // userId
    let displayName: String
    let status: String // "studying" | "break" | "left"
    let isReady: Bool
    let joinedAt: Date
    let workItemName: String?
    let workItemId: String?
    let workItemUpdatedAt: Date?
    let activeSeconds: Int
    let breakSeconds: Int
    let lastStatusChangedAt: Date?
    let leftAt: Date?
    let finalizedActiveSeconds: Int?
    let finalizedBreakSeconds: Int?

    var isStudying: Bool { status == "studying" }
    var isBreak: Bool { status == "break" }
    var hasLeft: Bool { status == "left" || status == "exited" }

    /// Calculates live display active seconds considering time elapsed since lastStatusChangedAt.
    func currentActiveSeconds(now: Date = Date()) -> Int {
        if let finalized = finalizedActiveSeconds {
            return finalized
        }
        var total = activeSeconds
        if isStudying, let lastChanged = lastStatusChangedAt {
            let elapsed = max(0, min(86400, Int(now.timeIntervalSince(lastChanged))))
            total += elapsed
        }
        return total
    }

    /// Calculates live display break seconds considering time elapsed since lastStatusChangedAt.
    func currentBreakSeconds(now: Date = Date()) -> Int {
        if let finalized = finalizedBreakSeconds {
            return finalized
        }
        var total = breakSeconds
        if isBreak, let lastChanged = lastStatusChangedAt {
            let elapsed = max(0, min(86400, Int(now.timeIntervalSince(lastChanged))))
            total += elapsed
        }
        return total
    }
}

/// Service handling Firestore room creation, joining, real-time snapshot listeners, and participant status updates.
@Observable
final class RoomService {

    static let shared = RoomService()

    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Room Code Generation

    /// Generates a random 6-character alphanumeric room code (uppercase).
    private func generateRoomCode() -> String {
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excluded confusing chars (I, O, 0, 1)
        return String((0..<6).compactMap { _ in letters.randomElement() })
    }

    // MARK: - Create Room

    /// Creates a new room in Firestore with a unique 6-character code and adds the host as first participant.
    func createRoom(
        durationInSeconds: Int,
        subject: String? = nil,
        workItemName: String? = nil,
        workItemId: String? = nil
    ) async throws -> (roomId: String, code: String) {
        guard durationInSeconds >= 60 && durationInSeconds <= 14400 else {
            throw NSError(domain: "Yonder", code: 400, userInfo: [NSLocalizedDescriptionKey: "Room duration must be between 1 minute and 4 hours."])
        }
        let trimmedSubject = subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedSubject.isEmpty else {
            throw NSError(domain: "Yonder", code: 400, userInfo: [NSLocalizedDescriptionKey: "Room subject is required."])
        }
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "Yonder", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        let currentUserId = currentUser.uid

        let code = try await uniqueRoomCode()
        let roomRef = db.collection("rooms").document(code)

        let startDate = Date()

        let roomData: [String: Any] = [
            "hostId": currentUserId,
            "duration": durationInSeconds,
            "status": "waiting",
            "subject": trimmedSubject,
            "participantCount": 1,
            "createdAt": Timestamp(date: startDate)
        ]

        try await roomRef.setData(roomData)

        // Add creator to participants collection
        let participantRef = roomRef.collection("participants").document(currentUserId)
        var participantData: [String: Any] = [
            "displayName": displayName(for: currentUser, fallback: "Host"),
            "status": "studying",
            "ready": true,
            "joinedAt": Timestamp(date: startDate),
            "activeSeconds": 0,
            "breakSeconds": 0,
            "lastStatusChangedAt": Timestamp(date: startDate)
        ]

        let finalWorkItem = (workItemName ?? subject)?.normalizedWorkItemNameOrNil
        if let finalWorkItem, !finalWorkItem.isEmpty {
            participantData["workItemName"] = finalWorkItem
            if let workItemId, !workItemId.isEmpty {
                participantData["workItemId"] = workItemId
            }
            participantData["workItemUpdatedAt"] = Timestamp(date: startDate)
        }

        try await participantRef.setData(participantData)

        return (code, code)
    }

    private var lastAttemptDate: Date? = nil
    private var failedJoinAttempts: Int = 0

    // MARK: - Join Room

    /// Joins an existing room using its 6-character code and adds the user as a participant.
    func joinRoom(
        code: String,
        workItemName: String? = nil,
        workItemId: String? = nil
    ) async throws -> String {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "Yonder", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let now = Date()
        if let last = lastAttemptDate {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < 1.0 {
                // Throttle rapid repeated attempts
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if failedJoinAttempts >= 5 && elapsed < 30.0 {
                throw NSError(domain: "Yonder", code: 429, userInfo: [NSLocalizedDescriptionKey: "Too many join attempts. Please wait 30 seconds."])
            }
        }
        lastAttemptDate = Date()

        let currentUserId = currentUser.uid
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let roomRef = db.collection("rooms").document(cleanCode)

        let participantRef = roomRef.collection("participants").document(currentUserId)
        var participantData: [String: Any] = [
            "displayName": displayName(for: currentUser, fallback: "Participant"),
            "status": "studying",
            "ready": false,
            "joinedAt": Timestamp(date: now),
            "activeSeconds": 0,
            "breakSeconds": 0,
            "lastStatusChangedAt": Timestamp(date: now)
        ]

        let trimmedWorkItem = workItemName?.normalizedWorkItemNameOrNil
        if let trimmedWorkItem, !trimmedWorkItem.isEmpty {
            participantData["workItemName"] = trimmedWorkItem
            if let workItemId, !workItemId.isEmpty {
                participantData["workItemId"] = workItemId
            }
            participantData["workItemUpdatedAt"] = Timestamp(date: now)
        }

        do {
            _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let roomSnapshot: DocumentSnapshot
                let participantSnapshot: DocumentSnapshot
                do {
                    roomSnapshot = try transaction.getDocument(roomRef)
                    participantSnapshot = try transaction.getDocument(participantRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                guard roomSnapshot.exists else {
                    let msg = Locale.current.language.languageCode?.identifier == "tr"
                        ? "Oda bulunamadı."
                        : "Room not found."
                    errorPointer?.pointee = NSError(domain: "Yonder", code: 404, userInfo: [NSLocalizedDescriptionKey: msg])
                    return nil
                }

                let data = roomSnapshot.data() ?? [:]
                let status = data["status"] as? String ?? "running"
                let endTimestamp = (data["endTimestamp"] as? Timestamp)?.dateValue()
                guard status != "ended" else {
                    let msg = Locale.current.language.languageCode?.identifier == "tr"
                        ? "Bu oda sona ermiş."
                        : "This room has ended."
                    errorPointer?.pointee = NSError(domain: "Yonder", code: 410, userInfo: [NSLocalizedDescriptionKey: msg])
                    return nil
                }
                guard status == "waiting" || (endTimestamp ?? Date.distantPast) > Date() else {
                    let msg = Locale.current.language.languageCode?.identifier == "tr"
                        ? "Bu oda sona ermiş."
                        : "This room has ended."
                    errorPointer?.pointee = NSError(domain: "Yonder", code: 410, userInfo: [NSLocalizedDescriptionKey: msg])
                    return nil
                }

                if participantSnapshot.exists {
                    // Re-entering active room: preserve existing timing fields!
                    var updateData: [String: Any] = [
                        "displayName": self.displayName(for: currentUser, fallback: "Participant")
                    ]
                    if let trimmedWorkItem, !trimmedWorkItem.isEmpty {
                        updateData["workItemName"] = trimmedWorkItem
                        if let workItemId, !workItemId.isEmpty {
                            updateData["workItemId"] = workItemId
                        }
                        updateData["workItemUpdatedAt"] = Timestamp(date: now)
                    }
                    transaction.updateData(updateData, forDocument: participantRef)
                } else {
                    transaction.setData(participantData, forDocument: participantRef)
                    transaction.updateData([
                        "participantCount": FieldValue.increment(Int64(1))
                    ], forDocument: roomRef)
                }

                return nil
            }
            failedJoinAttempts = 0
            return cleanCode
        } catch {
            failedJoinAttempts += 1
            throw error
        }
    }

    // MARK: - Listen to Room

    /// Listens for real-time changes to the room document.
    func listenToRoom(roomId: String, onChange: @escaping (RoomModel?) -> Void) -> ListenerRegistration {
        return db.collection("rooms").document(roomId)
            .addSnapshotListener { snapshot, error in
                guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                    onChange(nil)
                    return
                }

                let hostId = data["hostId"] as? String ?? ""
                let endTimestamp = (data["endTimestamp"] as? Timestamp)?.dateValue()
                let duration = data["duration"] as? Int ?? 0
                let status = data["status"] as? String ?? "running"
                let subject = data["subject"] as? String
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                let endedAt = (data["endedAt"] as? Timestamp)?.dateValue()

                let room = RoomModel(
                    id: snapshot.documentID,
                    hostId: hostId,
                    endTimestamp: endTimestamp,
                    duration: duration,
                    status: status,
                    subject: subject?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? subject : nil,
                    createdAt: createdAt,
                    endedAt: endedAt
                )

                onChange(room)
            }
    }

    // MARK: - Listen to Participants

    /// Listens for real-time changes to the room's participants collection.
    func listenToParticipants(roomId: String, onChange: @escaping ([ParticipantModel]) -> Void) -> ListenerRegistration {
        return db.collection("rooms").document(roomId).collection("participants")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }

                let participants = documents.compactMap { doc -> ParticipantModel? in
                    let data = doc.data()
                    let displayName = data["displayName"] as? String ?? ""
                    let status = data["status"] as? String ?? "studying"
                    let isReady = data["ready"] as? Bool ?? false
                    let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date()
                    let workItemName = data["workItemName"] as? String
                    let workItemId = data["workItemId"] as? String
                    let workItemUpdatedAt = (data["workItemUpdatedAt"] as? Timestamp)?.dateValue()
                    let activeSeconds = data["activeSeconds"] as? Int ?? 0
                    let breakSeconds = data["breakSeconds"] as? Int ?? 0
                    let lastStatusChangedAt = (data["lastStatusChangedAt"] as? Timestamp)?.dateValue()
                    let leftAt = (data["leftAt"] as? Timestamp)?.dateValue()
                    let finalizedActiveSeconds = data["finalizedActiveSeconds"] as? Int
                    let finalizedBreakSeconds = data["finalizedBreakSeconds"] as? Int

                    return ParticipantModel(
                        id: doc.documentID,
                        displayName: displayName,
                        status: status,
                        isReady: isReady,
                        joinedAt: joinedAt,
                        workItemName: workItemName?.normalizedWorkItemNameOrNil,
                        workItemId: workItemId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? workItemId : nil,
                        workItemUpdatedAt: workItemUpdatedAt,
                        activeSeconds: activeSeconds,
                        breakSeconds: breakSeconds,
                        lastStatusChangedAt: lastStatusChangedAt,
                        leftAt: leftAt,
                        finalizedActiveSeconds: finalizedActiveSeconds,
                        finalizedBreakSeconds: finalizedBreakSeconds
                    )
                }

                onChange(participants)
            }
    }

    // MARK: - Update Participant Work Item & Status

    /// Updates the current user's work item in the room participant document.
    func updateMyWorkItem(roomId: String, workItemName: String?, workItemId: String? = nil) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let participantRef = db.collection("rooms").document(roomId).collection("participants").document(currentUserId)
        let trimmedWorkItem = workItemName?.normalizedWorkItemNameOrNil

        if let trimmedWorkItem, !trimmedWorkItem.isEmpty {
            var dataToUpdate: [String: Any] = [
                "workItemName": trimmedWorkItem,
                "workItemUpdatedAt": Timestamp(date: Date())
            ]
            if let workItemId, !workItemId.isEmpty {
                dataToUpdate["workItemId"] = workItemId
            } else {
                dataToUpdate["workItemId"] = FieldValue.delete()
            }
            try await participantRef.updateData(dataToUpdate)
        } else {
            try await participantRef.updateData([
                "workItemName": FieldValue.delete(),
                "workItemId": FieldValue.delete(),
                "workItemUpdatedAt": FieldValue.delete()
            ])
        }
    }

    /// Updates the current user's status ("studying" | "break") in the room and accumulates active/break seconds atomically.
    func updateMyStatus(roomId: String, status newStatus: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let participantRef = db.collection("rooms").document(roomId).collection("participants").document(currentUserId)

        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(participantRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard snapshot.exists, let data = snapshot.data() else { return nil }

            let currentStatus = data["status"] as? String ?? "studying"
            guard currentStatus != newStatus else { return nil }

            var activeSecs = data["activeSeconds"] as? Int ?? 0
            var breakSecs = data["breakSeconds"] as? Int ?? 0
            let lastChangedAt = (data["lastStatusChangedAt"] as? Timestamp)?.dateValue() ?? Date()
            let now = Date()

            let rawElapsed = Int(now.timeIntervalSince(lastChangedAt))
            let elapsed = max(0, min(86400, rawElapsed))

            if currentStatus == "studying" {
                activeSecs += elapsed
            } else if currentStatus == "break" {
                breakSecs += elapsed
            }

            let updateData: [String: Any] = [
                "status": newStatus,
                "activeSeconds": activeSecs,
                "breakSeconds": breakSecs,
                "lastStatusChangedAt": Timestamp(date: now)
            ]

            transaction.updateData(updateData, forDocument: participantRef)
            return nil
        }
    }

    /// Finalizes the current user's active and break seconds upon room exit or room completion.
    func finalizeMyParticipantTime(roomId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let participantRef = db.collection("rooms").document(roomId).collection("participants").document(currentUserId)

        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(participantRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard snapshot.exists, let data = snapshot.data() else { return nil }

            let currentStatus = data["status"] as? String ?? "studying"
            var activeSecs = data["activeSeconds"] as? Int ?? 0
            var breakSecs = data["breakSeconds"] as? Int ?? 0
            let lastChangedAt = (data["lastStatusChangedAt"] as? Timestamp)?.dateValue() ?? Date()
            let now = Date()

            let rawElapsed = Int(now.timeIntervalSince(lastChangedAt))
            let elapsed = max(0, min(86400, rawElapsed))

            if currentStatus == "studying" {
                activeSecs += elapsed
            } else if currentStatus == "break" {
                breakSecs += elapsed
            }

            transaction.updateData([
                "activeSeconds": activeSecs,
                "breakSeconds": breakSecs,
                "finalizedActiveSeconds": activeSecs,
                "finalizedBreakSeconds": breakSecs,
                "leftAt": Timestamp(date: now)
            ], forDocument: participantRef)

            return nil
        }
    }

    /// Updates the current user's lobby ready state.
    func updateMyReadyState(roomId: String, isReady: Bool) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let participantRef = db.collection("rooms").document(roomId).collection("participants").document(currentUserId)
        try await participantRef.updateData(["ready": isReady])
    }

    /// Removes the current user from the room participant list. If this is the host or last participant,
    /// the room is ended in the same transaction so empty/orphaned rooms are not left active.
    func leaveRoom(roomId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }

        let roomRef = db.collection("rooms").document(roomId)
        let participantRef = roomRef.collection("participants").document(currentUserId)

        // Try finalizing time first before deleting participant document
        try? await finalizeMyParticipantTime(roomId: roomId)

        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let roomSnapshot: DocumentSnapshot
            let participantSnapshot: DocumentSnapshot
            do {
                roomSnapshot = try transaction.getDocument(roomRef)
                participantSnapshot = try transaction.getDocument(participantRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard roomSnapshot.exists, participantSnapshot.exists else { return nil }

            let data = roomSnapshot.data() ?? [:]
            let currentStatus = data["status"] as? String ?? ""
            let hostId = data["hostId"] as? String ?? ""
            let participantCount = data["participantCount"] as? Int ?? 1
            let remainingParticipantCount = max(0, participantCount - 1)

            transaction.deleteDocument(participantRef)

            if currentStatus != "ended", (remainingParticipantCount == 0 || currentUserId == hostId) {
                transaction.updateData([
                    "status": "ended",
                    "endedAt": Timestamp(date: Date()),
                    "participantCount": remainingParticipantCount
                ], forDocument: roomRef)
            } else {
                transaction.updateData([
                    "participantCount": remainingParticipantCount
                ], forDocument: roomRef)
            }

            return nil
        }
    }

    // MARK: - End Room

    /// Marks a room as ended safely if it is not already marked as ended.
    func endRoom(roomId: String) async throws {
        let roomRef = db.collection("rooms").document(roomId)

        // Finalize host's own participant doc time if present
        try? await finalizeMyParticipantTime(roomId: roomId)

        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let roomSnapshot: DocumentSnapshot
            do {
                roomSnapshot = try transaction.getDocument(roomRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let data = roomSnapshot.data() else { return nil }
            let currentStatus = data["status"] as? String ?? ""

            guard currentStatus != "ended" else { return nil }

            transaction.updateData([
                "status": "ended",
                "endedAt": Timestamp(date: Date())
            ], forDocument: roomRef)
            return nil
        }
    }

    // MARK: - Start Room

    /// Starts a waiting room atomically via transaction to prevent duplicate start operations.
    func startRoom(roomId: String) async throws {
        let roomRef = db.collection("rooms").document(roomId)

        _ = try await db.runTransaction { (transaction, errorPointer) -> Any? in
            let roomSnapshot: DocumentSnapshot
            do {
                roomSnapshot = try transaction.getDocument(roomRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard let data = roomSnapshot.data() else { return nil }
            let currentStatus = data["status"] as? String ?? ""

            // Only start if status is currently "waiting"
            guard currentStatus == "waiting" else { return nil }

            let duration = data["duration"] as? Int ?? 0
            let startDate = Date()
            let endDate = startDate.addingTimeInterval(TimeInterval(duration))

            transaction.updateData([
                "status": "running",
                "endTimestamp": Timestamp(date: endDate)
            ], forDocument: roomRef)

            return nil
        }
    }

    // MARK: - Helpers

    private func uniqueRoomCode() async throws -> String {
        for _ in 0..<8 {
            let code = generateRoomCode()
            let snapshot = try await db.collection("rooms").document(code).getDocument()
            if !snapshot.exists {
                return code
            }
        }

        throw NSError(domain: "Yonder", code: 409, userInfo: [NSLocalizedDescriptionKey: "Could not create a unique room code"])
    }

    private func displayName(for user: User, fallback: String) -> String {
        let candidates = [
            user.displayName,
            user.email?.components(separatedBy: "@").first,
            fallback
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? fallback
    }
}
