//
//  OrientationLock.swift
//  Yonder
//

import SwiftUI
import UIKit

@MainActor
final class OrientationLock {
    static let shared = OrientationLock()

    private var landscapeReasons: Set<String> = []
    private var orientationObserver: NSObjectProtocol?

    private init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        // Watches portrait / portraitUpsideDown so portrait-axis positions can
        // settle back into a real portrait layout. Upside-down is rendered by the
        // clock/timer views themselves, avoiding UIKit leaving SwiftUI in a
        // landscape-sized geometry on some iPhones.
        // landscapeLeft/landscapeRight are intentionally NOT handled here — those
        // rotations are left entirely to UIKit's own rotation coordinator, which
        // animates them natively and smoothly once the mask allows them.
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let orientationLock = self
            Task { @MainActor in
                orientationLock?.syncPortraitOrientationIfNeeded()
            }
        }
    }

    var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }
        return landscapeReasons.isEmpty
            ? .portrait
            : [.portrait, .landscapeLeft, .landscapeRight]
    }

    func allowPhoneLandscape(_ reason: String) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        landscapeReasons.insert(reason)
        updateSupportedOrientations()

        // If the phone is already being held sideways when landscape becomes
        // allowed, nudge the interface to match immediately — otherwise it stays
        // portrait until the next physical rotation.
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            requestGeometry(.portrait)
        case .landscapeLeft:
            // UIDeviceOrientation and UIInterfaceOrientation define landscapeLeft/Right
            // inverted from one another, so the mapping must be crossed here.
            requestGeometry(.landscapeRight)
        case .landscapeRight:
            requestGeometry(.landscapeLeft)
        default:
            break
        }
    }

    func lockPhonePortrait(_ reason: String) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        landscapeReasons.remove(reason)
        updateSupportedOrientations()

        if landscapeReasons.isEmpty {
            requestGeometry(.portrait)
        }
    }

    private func syncPortraitOrientationIfNeeded() {
        guard !landscapeReasons.isEmpty, UIDevice.current.userInterfaceIdiom == .phone else { return }

        switch UIDevice.current.orientation {
        case .portrait:
            requestGeometry(.portrait)
        case .portraitUpsideDown:
            requestGeometry(.portrait)
        default:
            break
        }
    }

    private func updateSupportedOrientations() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .forEach { scene in
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
    }

    private func requestGeometry(_ mask: UIInterfaceOrientationMask) {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .forEach { scene in
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { _ in }
            }
    }
}

private extension UIWindowScene {
    var keyWindow: UIWindow? {
        windows.first(where: \.isKeyWindow)
    }
}

private struct PhoneLandscapeAllowedModifier: ViewModifier {
    let reason: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                OrientationLock.shared.allowPhoneLandscape(reason)
            }
            .onDisappear {
                OrientationLock.shared.lockPhonePortrait(reason)
            }
    }
}

private struct PhoneUpsideDownContentModifier: ViewModifier {
    @State private var isUpsideDown = UIDevice.current.orientation == .portraitUpsideDown

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isUpsideDown ? 180 : 0))
            .transaction { transaction in
                transaction.animation = nil
            }
            .onAppear {
                update()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                update()
            }
    }

    private func update() {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            isUpsideDown = false
            return
        }

        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            isUpsideDown = true
        case .portrait, .landscapeLeft, .landscapeRight:
            isUpsideDown = false
        default:
            break
        }
    }
}

extension View {
    func allowsPhoneLandscape(_ reason: String) -> some View {
        modifier(PhoneLandscapeAllowedModifier(reason: reason))
    }

    func rotatesForPhoneUpsideDown() -> some View {
        modifier(PhoneUpsideDownContentModifier())
    }
}
