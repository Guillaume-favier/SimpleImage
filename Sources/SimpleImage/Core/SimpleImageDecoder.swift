//
//  SimpleImageDecoder.swift
//  SimpleImage
//

import Foundation
import ImageIO
import UIKit

/// Centralised image decoding.
///
/// The important difference from `UIImage(data:)` is that this decoder is
/// *animation aware*:
///
/// - For a multi-frame source (e.g. an animated GIF) it returns a still
///   first frame — keeping the existing `UIImage`-based API working — while
///   attaching a lazily-decoded `SimpleAnimatedImage` to it. No frames are
///   decoded up front.
/// - For everything else it behaves like `UIImage(data:)`.
public enum SimpleImageDecoder {
  /// Whether the data contains more than one frame.
  public static func isAnimated(data: Data) -> Bool {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      return false
    }
    return CGImageSourceGetCount(source) > 1
  }

  /// Wraps the given data in the appropriate ``ImageContainer``.
  ///
  /// Animated data (e.g. GIF) yields a ``GifContainer`` (`SimpleAnimatedImage`)
  /// that decodes frames lazily; everything else yields a ``StillImageContainer``.
  ///
  /// - Parameters:
  ///   - data: The compressed image data.
  ///   - scale: The scale of the produced `UIImage`s.
  ///   - maxPixelSize: An optional downsample target for animated frames.
  public static func container(
    for data: Data,
    scale: CGFloat = 1,
    maxPixelSize: CGFloat? = nil
  ) -> ImageContainer {
    if isAnimated(data: data),
      let animated = SimpleAnimatedImage(data: data, scale: scale, maxPixelSize: maxPixelSize)
    {
      return animated
    }
    return StillImageContainer(data: data)
  }

  /// Decodes the given data to a `UIImage` immediately.
  ///
  /// - Parameters:
  ///   - data: The compressed image data.
  ///   - scale: The scale of the produced `UIImage`.
  ///   - maxPixelSize: An optional downsample target. When provided, animated
  ///     frames are decoded at most this many pixels on their longest edge.
  public static func decode(
    data: Data,
    scale: CGFloat = 1,
    maxPixelSize: CGFloat? = nil
  ) -> UIImage? {
    if isAnimated(data: data),
      let animated = SimpleAnimatedImage(data: data, scale: scale, maxPixelSize: maxPixelSize),
      let image = animated.makeRepresentativeImage()
    {
      return image
    }

    return UIImage(data: data)
  }
}
