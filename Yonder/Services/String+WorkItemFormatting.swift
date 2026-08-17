//
//  String+WorkItemFormatting.swift
//  Yonder
//

import Foundation
import SwiftUI

extension String {

    /// Normalizes a work area name to Title Case using Turkish locale rules by default.
    /// Trims leading/trailing whitespace and collapses multiple internal spaces into a single space.
    ///
    /// Examples:
    /// - "fizik" → "Fizik"
    /// - "FİZİK" → "Fizik"
    /// - "matematik" → "Matematik"
    /// - "türkçe" → "Türkçe"
    /// - "TÜRKÇE" → "Türkçe"
    /// - "İNGİLİZCE" → "İngilizce"
    /// - "türk dili" → "Türk Dili"
    /// - "yks matematik" → "Yks Matematik"
    func normalizedWorkItemName(localeIdentifier: String = "tr_TR") -> String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Collapse internal whitespace
        let components = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let cleaned = components.joined(separator: " ")

        let locale = Locale(identifier: localeIdentifier)
        return cleaned.capitalized(with: locale)
    }

    /// Returns the normalized work item name, or `nil` if the resulting string is empty.
    var normalizedWorkItemNameOrNil: String? {
        let norm = normalizedWorkItemName()
        return norm.isEmpty ? nil : norm
    }
}

enum WorkItemColorPalette {
    static let unnamedColor = Color(white: 0.45)

    private static let colors: [Color] = [
        Color(red: 0.45, green: 0.85, blue: 0.65),
        Color(red: 0.42, green: 0.82, blue: 0.88),
        Color(red: 0.95, green: 0.78, blue: 0.35),
        Color(red: 0.88, green: 0.55, blue: 0.75),
        Color(red: 0.60, green: 0.70, blue: 0.95),
        Color(red: 0.95, green: 0.72, blue: 0.45),
        Color(red: 0.75, green: 0.62, blue: 0.92)
    ]

    static func color(for name: String, unnamedLabel: String? = nil) -> Color {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let unnamedLabel,
           trimmed.localizedCaseInsensitiveCompare(unnamedLabel) == .orderedSame {
            return unnamedColor
        }

        let key = stableKey(for: trimmed)
        guard !key.isEmpty else { return unnamedColor }

        return colors[stableHash(key) % colors.count]
    }

    private static func stableKey(for name: String) -> String {
        name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "tr_TR"))
    }

    private static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(colors.count))
    }
}
