//
//  WeeklySubjectIntentionStore.swift
//  Yonder
//
//  Persists weekly focus intention targets per subject using UserDefaults JSON storage.
//

import Foundation

/// Manages subject-level weekly focus intentions.
final class WeeklySubjectIntentionStore {

    static let shared = WeeklySubjectIntentionStore()

    private let userDefaultsKey = "weekly_subject_intentions_json"

    private init() {}

    /// Loads all subject intentions as a dictionary of `[NormalizedSubjectKey: Int]`.
    func load() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return dict
    }

    /// Saves the given subject intentions dictionary.
    func save(_ dict: [String: Int]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Returns the weekly target duration in seconds for a specific subject (0 if none).
    func intentionSeconds(for subject: String) -> Int {
        let key = normalize(subject)
        guard !key.isEmpty else { return 0 }
        return load()[key] ?? 0
    }

    /// Sets or removes the weekly target duration in seconds for a specific subject.
    func setIntentionSeconds(_ seconds: Int, for subject: String) {
        let key = normalize(subject)
        guard !key.isEmpty else { return }

        var current = load()
        if seconds > 0 {
            current[key] = seconds
        } else {
            current.removeValue(forKey: key)
        }
        save(current)
    }

    /// Helper to normalize subject keys for case-insensitive and whitespace-insensitive matching.
    private func normalize(_ subject: String) -> String {
        subject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
