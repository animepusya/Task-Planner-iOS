//
//  ScrollViewOffsetObserver.swift
//  Task Planner
//
//  Created by Codex on 14.04.2026.
//

import SwiftUI
import UIKit

enum ScrollViewOffsetMeasurement {
    case adjustedContentInsetTop
    case relativeToInitialOffset
}

struct ScrollViewOffsetObserver: UIViewRepresentable {
    let measurement: ScrollViewOffsetMeasurement
    let onOffsetChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            measurement: measurement,
            onOffsetChange: onOffsetChange
        )
    }

    func makeUIView(context: Context) -> ObservationView {
        let view = ObservationView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ObservationView, context: Context) {
        context.coordinator.measurement = measurement
        context.coordinator.onOffsetChange = onOffsetChange
        uiView.coordinator = context.coordinator

        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }
}

extension ScrollViewOffsetObserver {
    final class Coordinator: NSObject {
        var measurement: ScrollViewOffsetMeasurement
        var onOffsetChange: (CGFloat) -> Void

        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var initialContentOffsetY: CGFloat?

        init(
            measurement: ScrollViewOffsetMeasurement,
            onOffsetChange: @escaping (CGFloat) -> Void
        ) {
            self.measurement = measurement
            self.onOffsetChange = onOffsetChange
        }

        func attachIfNeeded(from view: UIView) {
            guard let resolvedScrollView = findScrollView(from: view) else { return }

            if scrollView !== resolvedScrollView {
                contentOffsetObservation = nil
                scrollView = resolvedScrollView
                initialContentOffsetY = nil
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
            let effectiveOffset: CGFloat

            switch measurement {
            case .adjustedContentInsetTop:
                effectiveOffset = max(
                    0,
                    scrollView.contentOffset.y + scrollView.adjustedContentInset.top
                )
            case .relativeToInitialOffset:
                let currentOffsetY = scrollView.contentOffset.y

                if let baseline = initialContentOffsetY {
                    let isInteracting = scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating
                    if !isInteracting && currentOffsetY < baseline {
                        initialContentOffsetY = currentOffsetY
                    }
                } else {
                    initialContentOffsetY = currentOffsetY
                }

                effectiveOffset = max(0, currentOffsetY - (initialContentOffsetY ?? currentOffsetY))
            }

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
        measurement: ScrollViewOffsetMeasurement = .adjustedContentInsetTop,
        perform action: @escaping (CGFloat) -> Void
    ) -> some View {
        background {
            ScrollViewOffsetObserver(
                measurement: measurement,
                onOffsetChange: action
            )
            .frame(width: 0, height: 0)
        }
    }
}
