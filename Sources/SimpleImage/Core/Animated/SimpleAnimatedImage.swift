//
//  SimpleAnimatedImage.swift
//  SimpleImage
//

import Foundation
import ImageIO
import UIKit

public final class SimpleAnimatedImage: @unchecked Sendable {
  public static let defaultCachedFrameLimit = 8

  public let data: Data
  public let frameCount: Int
  public let loopCount: Int
  public let totalDuration: TimeInterval
  public let size: CGSize
  public let scale: CGFloat

  private let source: CGImageSource
  private let maxPixelSize: CGFloat?
  private let delays: [TimeInterval]
  private let queue = DispatchQueue(label: "com.simpleimage.animated.decoder", qos: .userInitiated)
  private let frameCache = NSCache<NSNumber, UIImage>()

  public var isAnimated: Bool { frameCount > 1 }

  public var cachedFrameLimit: Int {
    get { frameCache.countLimit }
    set { frameCache.countLimit = max(1, newValue) }
  }

  public init?(data: Data, scale: CGFloat = 1, maxPixelSize: CGFloat? = nil) {
    // kCGImageSourceShouldCache: false keeps ImageIO from caching every frame.
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

  public var firstFrame: UIImage? { image(at: 0) }

  public func delay(at index: Int) -> TimeInterval {
    guard !delays.isEmpty else { return Self.defaultDelay }
    let resolvedIndex = ((index % delays.count) + delays.count) % delays.count
    return delays[resolvedIndex]
  }

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

  public func clearFrameCache() {
    frameCache.removeAllObjects()
  }

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

    // Browsers clamp anything below 20 ms to 100 ms.
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
  public func uiImage() async throws -> UIImage {
    guard let image = makeRepresentativeImage() else {
      throw SimpleImageError.invalidImageData
    }
    return image
  }
}
