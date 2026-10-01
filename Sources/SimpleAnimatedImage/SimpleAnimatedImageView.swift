//
//  SimpleAnimatedImageView.swift
//  SimpleAnimatedImage
//

@preconcurrency import Gifu
import UIKit

/// Gifu-backed animated image view.
///
/// Playback, frame buffering and decoding are offloaded to Gifu — this target
/// is the only one in the package that depends on it.
@MainActor
public final class SimpleAnimatedImageView: UIView {
    private let gifView = GIFImageView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        gifView.frame = bounds
        gifView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(gifView)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        gifView.frame = bounds
        gifView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(gifView)
    }

    public func setAnimatedImage(data: Data) {
        gifView.animate(withGIFData: data)
    }

    public func stopAnimating() {
        gifView.stopAnimatingGIF()
    }
}
