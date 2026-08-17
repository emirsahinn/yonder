//
//  LanguageService.swift
//  Yonder
//

import Foundation
import SwiftUI

/// Manages native SwiftUI locale selection between Turkish ("tr") and English ("en").
final class LanguageService {

    static let shared = LanguageService()

    private init() {}

    /// Syncs AppleLanguages in UserDefaults for system compatibility.
    func applyLanguage(_ lang: String) {
        let validLang = (lang == "en") ? "en" : "tr"
        UserDefaults.standard.set([validLang], forKey: "AppleLanguages")
    }
}

extension String {
    static func localized(_ key: String, lang: String) -> String {
        let validLang = (lang == "en") ? "en" : "tr"
        guard let path = Bundle.main.path(forResource: validLang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
}
	
