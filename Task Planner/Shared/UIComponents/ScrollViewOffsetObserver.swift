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

struct ScrollViewOffsetReader: View {
    let measurement: ScrollViewOffsetMeasurement
    let perform: (CGFloat) -> Void

    init(
        measurement: ScrollViewOffsetMeasurement = .adjustedContentInsetTop,
        perform: @escaping (CGFloat) -> Void
    ) {
        self.measurement = measurement
        self.perform = perform
    }

    var body: some View {
        // The probe must live inside the scroll content branch so it can bind to
        // the nearest enclosing scroll view without ever walking into sibling tabs.
        Color.clear
            .frame(height: 0)
            .background {
                ScrollViewOffsetObserverRepresentable(
                    measurement: measurement,
                    onOffsetChange: perform
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct ScrollViewOffsetObserverRepresentable: UIViewRepresentable {
    let measurement: ScrollViewOffsetMeasurement
    let onOffsetChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            measurement: measurement,
            onOffsetChange: onOffsetChange
        )
    }

    func makeUIView(context: Context) -> ScrollViewObservationView {
        let view = ScrollViewObservationView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ScrollViewObservationView, context: Context) {
        context.coordinator.measurement = measurement
        context.coordinator.onOffsetChange = onOffsetChange
        uiView.coordinator = context.coordinator

        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: uiView)
        }
    }
}

private extension ScrollViewOffsetObserverRepresentable {
    final class Coordinator: NSObject {
        var measurement: ScrollViewOffsetMeasurement
        var onOffsetChange: (CGFloat) -> Void

        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var contentInsetObservation: NSKeyValueObservation?
        private var boundsObservation: NSKeyValueObservation?
        private var initialContentOffsetY: CGFloat?
        private var pendingOffset: CGFloat?
        private var isDeliveryScheduled = false

        init(
            measurement: ScrollViewOffsetMeasurement,
            onOffsetChange: @escaping (CGFloat) -> Void
        ) {
            self.measurement = measurement
            self.onOffsetChange = onOffsetChange
        }

        func attachIfNeeded(from view: UIView) {
            guard let resolvedScrollView = view.enclosingScrollView else { return }

            if scrollView !== resolvedScrollView {
                contentOffsetObservation = nil
                contentInsetObservation = nil
                boundsObservation = nil
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

            contentInsetObservation = scrollView.observe(
                \.contentInset,
                options: [.initial, .new]
            ) { [weak self] scrollView, _ in
                self?.notifyOffset(from: scrollView)
            }

            boundsObservation = scrollView.observe(
                \.bounds,
                options: [.new]
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

            queueOffsetDelivery(effectiveOffset)
        }

        private func queueOffsetDelivery(_ offset: CGFloat) {
            pendingOffset = offset
            guard !isDeliveryScheduled else { return }
            isDeliveryScheduled = true

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isDeliveryScheduled = false

                guard let offset = self.pendingOffset else { return }
                self.pendingOffset = nil
                self.onOffsetChange(offset)
            }
        }
    }
}

private final class ScrollViewObservationView: UIView {
    weak var coordinator: ScrollViewOffsetObserverRepresentable.Coordinator?
    private var isRefreshScheduled = false
    private var lastBoundsSize: CGSize = .zero

    override func didMoveToWindow() {
        super.didMoveToWindow()
        scheduleRefresh()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        scheduleRefresh()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != lastBoundsSize else { return }
        lastBoundsSize = bounds.size
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        guard !isRefreshScheduled else { return }
        isRefreshScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isRefreshScheduled = false
            self.coordinator?.attachIfNeeded(from: self)
        }
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var current = superview

        while let candidate = current {
            if let scrollView = candidate as? UIScrollView {
                return scrollView
            }

            current = candidate.superview
        }

        return nil
    }
}
