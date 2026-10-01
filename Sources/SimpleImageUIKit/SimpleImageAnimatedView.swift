//
//  SimpleImageAnimatedView.swift
//  SimpleImageUIKit
//

import Foundation
import SimpleImage
import UIKit

/// A `UIImageView` subclass that plays `SimpleAnimatedImage` content (such as
/// animated GIFs) efficiently.
///
/// Playback is driven by a `CADisplayLink` and only the frames near the playhead
/// are decoded. This is the opposite of `UIImage.animatedImage(with:duration:)`,
/// which decodes every frame up front.
///
/// Usage:
/// ```swift
/// let view = SimpleImageAnimatedView()
/// view.si_animatedImage = myAnimatedImage
/// // or load through the pipeline:
/// view.si_setAnimatedImage(using: manager, request: request)
/// ```
@MainActor
public final class SimpleImageAnimatedView: UIImageView {
  private nonisolated(unsafe) var displayLink: CADisplayLink?

  private var animatedImage: SimpleAnimatedImage?
  private var currentFrameIndex = 0
  private var elapsed: TimeInterval = 0
  private var completedLoops = 0
  private var isPlaying = false

  /// The animated image being played. Setting it restarts playback from frame 0.
  public var si_animatedImage: SimpleAnimatedImage? {
    get { animatedImage }
    set { apply(animatedImage: newValue) }
  }

  /// Whether playback is currently active.
  public var si_isPlaying: Bool { isPlaying }

  public override init(frame: CGRect) {
    super.init(frame: frame)
  }

  /// Lets callers write `SimpleImageAnimatedView()`.
  public convenience init() {
    self.init(frame: .zero)
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  deinit {
    displayLink?.invalidate()
    displayLink = nil
  }

  public override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if newWindow == nil {
      stopPlayback()
    } else if animatedImage?.isAnimated == true {
      startPlayback()
    }
  }

  /// Starts playback if it isn't already running.
  public func si_startAnimating() {
    startPlayback()
  }

  /// Pauses playback, keeping the current frame on screen.
  public func si_stopAnimating() {
    stopPlayback()
  }

  // MARK: - Playback

  private func apply(animatedImage newValue: SimpleAnimatedImage?) {
    stopPlayback()
    animatedImage = newValue
    currentFrameIndex = 0
    elapsed = 0
    completedLoops = 0

    guard let newValue else { return }
    image = newValue.image(at: 0)
    if newValue.isAnimated && window != nil {
      startPlayback()
    }
  }

  private func startPlayback() {
    guard !isPlaying, let animatedImage, animatedImage.isAnimated else { return }
    isPlaying = true
    let proxy = DisplayLinkProxy(target: self)
    let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.step(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  private func stopPlayback() {
    isPlaying = false
    displayLink?.invalidate()
    displayLink = nil
  }

  fileprivate func advance(by delta: TimeInterval) {
    guard let animatedImage, animatedImage.isAnimated else {
      stopPlayback()
      return
    }

    elapsed += delta
    var didAdvance = false
    var steps = 0

    // Cap the number of frames advanced in a single tick so a stalled display
    // link can never spin the run loop.
    while elapsed >= animatedImage.delay(at: currentFrameIndex), steps < animatedImage.frameCount {
      elapsed -= animatedImage.delay(at: currentFrameIndex)
      currentFrameIndex += 1
      steps += 1

      if currentFrameIndex >= animatedImage.frameCount {
        currentFrameIndex = 0
        completedLoops += 1
        // GIF spec: loop count 0 = infinite; N = N *additional* loops after the
        // first play (so N = 1 plays twice). Stop only once we've wrapped past
        // the requested repeat count.
        if animatedImage.loopCount > 0, completedLoops > animatedImage.loopCount {
          stopPlayback()
          return
        }
      }
      didAdvance = true
    }

    guard didAdvance else { return }
    image = animatedImage.image(at: currentFrameIndex)
    animatedImage.prefetch(from: currentFrameIndex)
  }
}

/// Breaks the retain cycle between a `CADisplayLink` (which retains its target)
/// and the view.
private final class DisplayLinkProxy: NSObject {
  weak var target: SimpleImageAnimatedView?

  init(target: SimpleImageAnimatedView) {
    self.target = target
  }

  @objc @MainActor func step(_ link: CADisplayLink) {
    target?.advance(by: link.duration)
  }
}
