//
//  SimpleImageDecoder.swift
//  SimpleImage
//

import Foundation
import ImageIO
import UIKit

public enum SimpleImageDecoder {
  public static func isAnimated(data: Data) -> Bool {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
      return false
    }
    return CGImageSourceGetCount(source) > 1
  }

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
