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

    public override var contentMode: UIView.ContentMode {
        get { super.contentMode }
        set {
            super.contentMode = newValue
            gifView.contentMode = newValue
        }
    }

    public var frameCount: Int { gifView.frameCount }
    public var loopDuration: TimeInterval { gifView.gifLoopDuration }
    public var isAnimating: Bool { gifView.isAnimatingGIF }

    /// Loads the GIF, shows the first frame, and starts playing.
    public func setAnimatedImage(data: Data) {
        gifView.animate(withGIFData: data)
    }

    /// Decodes frames into the buffer without starting playback.
    /// `completion` is called once the buffer is ready.
    public func prepareForAnimation(data: Data, completion: @escaping () -> Void) {
        gifView.prepareForAnimation(withGIFData: data, completionHandler: completion)
    }

    /// Number of decoded frames Gifu keeps buffered (default 50).
    public func setFrameBufferSize(_ count: Int) {
        gifView.setFrameBufferSize(count)
    }

    public func startAnimating() {
        gifView.startAnimatingGIF()
    }

    public func stopAnimating() {
        gifView.stopAnimatingGIF()
    }
}
