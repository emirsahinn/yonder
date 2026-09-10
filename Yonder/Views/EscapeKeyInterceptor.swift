//
//  EscapeKeyInterceptor.swift
//  Yonder
//
//  Captures hardware/simulator Escape key presses before UIKit treats them as
//  a modal dismissal command.
//

import SwiftUI
import UIKit

struct EscapeKeyInterceptor: UIViewRepresentable {
    var onEscape: () -> Void

    func makeUIView(context: Context) -> EscapeKeyCatcherView {
        let view = EscapeKeyCatcherView()
        view.onEscape = onEscape
        DispatchQueue.main.async {
            view.becomeFirstResponder()
        }
        return view
    }

    func updateUIView(_ uiView: EscapeKeyCatcherView, context: Context) {
        uiView.onEscape = onEscape
        // Do not re-claim first responder here: this runs on every SwiftUI
        // diff of the view it's attached to, which was stealing focus from
        // any TextField the user tapped in a sheet presented above it
        // (e.g. work area name fields), making the keyboard never appear.
    }
}

final class EscapeKeyCatcherView: UIView {
    var onEscape: (() -> Void)?

    override var canBecomeFirstResponder: Bool {
        true
    }

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                input: UIKeyCommand.inputEscape,
                modifierFlags: [],
                action: #selector(handleEscape)
            )
        ]
    }

    @objc private func handleEscape() {
        onEscape?()
    }
}
