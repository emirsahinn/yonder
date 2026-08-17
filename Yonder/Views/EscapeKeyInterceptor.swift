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
        DispatchQueue.main.async {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
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
