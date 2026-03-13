//
//  TaskEditorDismissKeyboardOnTap.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import SwiftUI
import UIKit

struct TaskEditorDismissKeyboardOnTapModifier: ViewModifier {
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.background(
            TaskEditorTapOutsideDismissView(onDismiss: onDismiss)
        )
    }
}

extension View {
    func taskEditorDismissKeyboardOnTap(onDismiss: @escaping () -> Void) -> some View {
        modifier(TaskEditorDismissKeyboardOnTapModifier(onDismiss: onDismiss))
    }
}

private struct TaskEditorTapOutsideDismissView: UIViewRepresentable {
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    func makeUIView(context: Context) -> PassthroughView {
        let view = PassthroughView()
        let recognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap)
        )
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: PassthroughView, context: Context) {
        context.coordinator.onDismiss = onDismiss
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        @objc
        func handleTap() {
            onDismiss()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = touch.view else { return true }

            if view.closestSuperview(of: UITextField.self) != nil { return false }
            if view.closestSuperview(of: UITextView.self) != nil { return false }

            return true
        }
    }
}

private final class PassthroughView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension UIView {
    func closestSuperview<T: UIView>(of type: T.Type) -> T? {
        var current: UIView? = self

        while let node = current {
            if let typed = node as? T {
                return typed
            }
            current = node.superview
        }

        return nil
    }
}
