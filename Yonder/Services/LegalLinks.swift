//
//  LegalLinks.swift
//  Yonder
//

import Foundation

/// Central source of truth for legal URLs shown across the app (paywall, settings, etc).
enum LegalLinks {
    static let privacyPolicyURL = URL(string: "https://yonderfocusapp.com/privacy")!

    /// Apple's Standard EULA, used in place of custom Terms of Use.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
