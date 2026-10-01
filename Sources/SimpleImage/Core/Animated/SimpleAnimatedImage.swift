//
//  SimpleAnimatedImage.swift
//  SimpleImage
//

import Foundation
import ImageIO
import UIKit

/// A lazily-decoded, memory-bounded animated image (GIF, and any other
/// multi-frame format ImageIO can read).
///
/// Unlike `UIImage.animatedImage(with:duration:)` — which materialises **every**
/// frame as a decoded bitmap up front and keeps them alive for the lifetime of
/// the object — `SimpleAnimatedImage` decodes frames on demand and retains only a
/// small, bounded window of decoded frames in an `NSCache`.
///
/// The compressed source `data` is kept around so it can be written to / read
/// from the disk cache without ever re-encoding (which would flatten the
/// animation).
public final class SimpleAnimatedImage: @unchecked Sendable {
  /// The default maximum number of decoded frames kept in memory.
  public static let defaultCachedFrameLimit = 8

  /// The original, compressed image bytes.
  public let data: Data
  /// The number of frames in the animation.
  public let frameCount: Int
  /// The number of times the animation should loop. `0` means infinitely.
  public let loopCount: Int
  /// The summed duration of a single playback loop.
  public let totalDuration: TimeInterval
  /// The pixel size of the animation.
  public let size: CGSize
  /// The scale used for the produced `UIImage`s.
  public let scale: CGFloat

  private let source: CGImageSource
  private let maxPixelSize: CGFloat?
  private let delays: [TimeInterval]
  private let queue = DispatchQueue(label: "com.simpleimage.animated.decoder", qos: .userInitiated)
  private let frameCache = NSCache<NSNumber, UIImage>()

  /// `true` when the image contains more than one frame.
  public var isAnimated: Bool { frameCount > 1 }

  /// The maximum number of decoded frames retained in memory.
  public var cachedFrameLimit: Int {
    get { frameCache.countLimit }
    set { frameCache.countLimit = max(1, newValue) }
  }

  /// Creates an animated image from compressed data.
  ///
  /// - Parameters:
  ///   - data: The compressed image data (e.g. GIF bytes).
  ///   - scale: The scale of the produced `UIImage`s. Defaults to `1`.
  ///   - maxPixelSize: When provided, frames are downsampled so their longest
  ///     edge is at most this many pixels. Downsampling drastically reduces the
  ///     memory used per decoded frame.
  public init?(data: Data, scale: CGFloat = 1, maxPixelSize: CGFloat? = nil) {
    // `kCGImageSourceShouldCache: false` is critical: we want *no* implicit
    // frame caching at the ImageIO level, because that is precisely the
    // "insanely inefficient" behaviour this type exists to avoid.
    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary)
    else {
      return nil
    }

    let count = CGImageSourceGetCount(source)
    guard count > 0 else { return nil }

    var delays: [TimeInterval] = []
    delays.reserveCapacity(count)
    for index in 0..<count {
      delays.append(Self.delay(for: source, at: index))
    }

    self.data = data
    self.source = source
    self.maxPixelSize = maxPixelSize
    self.frameCount = count
    self.loopCount = Self.loopCount(for: source)
    self.size = Self.pixelSize(for: source)
    self.scale = scale
    self.delays = delays
    self.totalDuration = delays.reduce(0, +)
    self.frameCache.countLimit = Self.defaultCachedFrameLimit
  }

  /// The frame at the given index, decoding it if it isn't already cached.
  public func image(at index: Int) -> UIImage? {
    guard frameCount > 0 else { return nil }
    let resolvedIndex = ((index % frameCount) + frameCount) % frameCount
    let key = NSNumber(value: resolvedIndex)

    if let cached = frameCache.object(forKey: key) {
      return cached
    }

    let decoded = queue.sync { self.decodeFrame(at: resolvedIndex) }
    if let decoded {
      frameCache.setObject(decoded, forKey: key)
    }
    return decoded
  }

  /// The first frame, suitable as a static placeholder.
  public var firstFrame: UIImage? { image(at: 0) }

  /// The display duration of the frame at the given index (clamped like browsers).
  public func delay(at index: Int) -> TimeInterval {
    guard !delays.isEmpty else { return Self.defaultDelay }
    let resolvedIndex = ((index % delays.count) + delays.count) % delays.count
    return delays[resolvedIndex]
  }

  /// Warms the frame cache for the frames following `index`.
  ///
  /// Call this from the playback loop so the next frames are ready by the time
  /// they need to be displayed.
  public func prefetch(from index: Int, count: Int = 2) {
    guard isAnimated, count > 0 else { return }
    let start = ((index % frameCount) + frameCount) % frameCount
    queue.async { [weak self] in
      guard let self else { return }
      for offset in 1...count {
        let frameIndex = (start + offset) % self.frameCount
        let key = NSNumber(value: frameIndex)
        guard self.frameCache.object(forKey: key) == nil else { continue }
        if let decoded = self.decodeFrame(at: frameIndex) {
          self.frameCache.setObject(decoded, forKey: key)
        }
      }
    }
  }

  /// Drops every decoded frame, releasing the associated bitmaps.
  public func clearFrameCache() {
    frameCache.removeAllObjects()
  }

  /// Returns the first frame with this animation attached to it.
  ///
  /// This is what the pipeline surfaces when callers only want a `UIImage`: the
  /// still is immediately renderable, while `si_animatedImage` gives access to
  /// the frames when a caller wants to play them.
  public func makeRepresentativeImage() -> UIImage? {
    guard let firstFrame else { return nil }
    firstFrame.si_animatedImage = self
    return firstFrame
  }

  // MARK: - Decoding

  private func decodeFrame(at index: Int) -> UIImage? {
    let cgImage: CGImage?

    if let maxPixelSize {
      let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
      ]
      cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    } else {
      let options: [CFString: Any] = [
        kCGImageSourceShouldCache: false,
        kCGImageSourceShouldCacheImmediately: true,
      ]
      cgImage = CGImageSourceCreateImageAtIndex(source, index, options as CFDictionary)
    }

    guard let cgImage else { return nil }
    return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
  }

  // MARK: - Metadata

  private static let defaultDelay: TimeInterval = 0.1

  /// Reads the frame delay without decoding the frame's bitmap.
  private static func delay(for source: CGImageSource, at index: Int) -> TimeInterval {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
      let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
    else {
      return defaultDelay
    }

    let unclamped = (gif[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber)?.doubleValue
    let clamped = (gif[kCGImagePropertyGIFDelayTime] as? NSNumber)?.doubleValue
    let value = unclamped ?? clamped ?? defaultDelay

    // Match modern browsers: anything faster than 20 ms is rendered as 100 ms.
    return value < 0.02 ? defaultDelay : value
  }

  private static func loopCount(for source: CGImageSource) -> Int {
    guard
      let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any],
      let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
      let loop = gif[kCGImagePropertyGIFLoopCount] as? NSNumber
    else {
      return 0
    }
    return loop.intValue
  }

  private static func pixelSize(for source: CGImageSource) -> CGSize {
    guard
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else {
      return .zero
    }
    let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
    let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
    return CGSize(width: width, height: height)
  }
}

extension SimpleAnimatedImage: ImageContainer {
  /// Returns the representative (first) frame with this animation attached.
  ///
  /// This is what the pipeline surfaces when callers only want a `UIImage`:
  /// the still is immediately renderable, while `si_animatedImage` enables
  /// frame-by-frame playback.
  public func uiImage() async throws -> UIImage {
    guard let image = makeRepresentativeImage() else {
      throw SimpleImageError.invalidImageData
    }
    return image
  }
}
