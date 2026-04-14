//
//  ScrollViewOffsetObserver.swift
//  Task Planner
//
//  Created by Codex on 14.04.2026.
//

import SwiftUI
import UIKit

struct ScrollViewOffsetObserver: UIViewRepresentable {
    let onOffsetChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOffsetChange: onOffsetChange)
    }

    func makeUIView(context: Context) -> ObservationView {
        let view = ObservationView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ObservationView, context: Context) {
        context.coordinator.onOffsetChange = onOffsetChange
        uiView.coordinator = context.coordinator

        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }
}

extension ScrollViewOffsetObserver {
    final class Coordinator: NSObject {
        var onOffsetChange: (CGFloat) -> Void

        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?

        init(onOffsetChange: @escaping (CGFloat) -> Void) {
            self.onOffsetChange = onOffsetChange
        }

        func attachIfNeeded(from view: UIView) {
            guard let resolvedScrollView = findScrollView(from: view) else { return }

            if scrollView !== resolvedScrollView {
                contentOffsetObservation = nil
                scrollView = resolvedScrollView
                observe(scrollView: resolvedScrollView)
            }

            notifyOffset(from: resolvedScrollView)
        }

        private func observe(scrollView: UIScrollView) {
            contentOffsetObservation = scrollView.observe(
                \.contentOffset,
                options: [.initial, .new]
            ) { [weak self] scrollView, _ in
                self?.notifyOffset(from: scrollView)
            }
        }

        private func notifyOffset(from scrollView: UIScrollView) {
            let effectiveOffset = max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            onOffsetChange(effectiveOffset)
        }

        private func findScrollView(from view: UIView) -> UIScrollView? {
            var current: UIView? = view

            while let candidate = current {
                if let scrollView = candidate as? UIScrollView {
                    return scrollView
                }

                if let descendant = findScrollViewInTree(candidate) {
                    return descendant
                }

                current = candidate.superview
            }

            return nil
        }

        private func findScrollViewInTree(_ root: UIView) -> UIScrollView? {
            for subview in root.subviews {
                if let scrollView = subview as? UIScrollView {
                    return scrollView
                }

                if let nestedScrollView = findScrollViewInTree(subview) {
                    return nestedScrollView
                }
            }

            return nil
        }
    }
}

final class ObservationView: UIView {
    weak var coordinator: ScrollViewOffsetObserver.Coordinator?

    override func didMoveToWindow() {
        super.didMoveToWindow()

        DispatchQueue.main.async { [weak self] in
            guard let self, let coordinator else { return }
            coordinator.attachIfNeeded(from: self)
        }
    }
}

extension View {
    func onScrollViewOffsetChange(
        perform action: @escaping (CGFloat) -> Void
    ) -> some View {
        background {
            ScrollViewOffsetObserver(onOffsetChange: action)
                .frame(width: 0, height: 0)
        }
    }
}
