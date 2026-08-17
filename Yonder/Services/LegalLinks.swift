//
//  LegalLinks.swift
//  Yonder
//

import Foundation

/// Central source of truth for legal URLs shown across the app (paywall, settings, etc).
enum LegalLinks {
    /// Temporary Privacy Policy URL — replace with the final hosted policy before submission.
    static let privacyPolicyURL = URL(string: "https://emirsahin.notion.site/yonder-privacy")!

    /// Apple's Standard EULA, used in place of custom Terms of Use.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
