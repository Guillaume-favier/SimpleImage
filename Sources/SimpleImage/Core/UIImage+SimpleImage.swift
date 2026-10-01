//
//  UIImage+SimpleImage.swift
//  SimpleImage
//

import Foundation
import UIKit

private enum SimpleImageAssociatedKeys {
  nonisolated(unsafe) static var animatedImage: UInt8 = 0
}

extension UIImage {
  /// The animated source backing this image, when it was decoded from an
  /// animated format such as GIF.
  public var si_animatedImage: SimpleAnimatedImage? {
    get {
      objc_getAssociatedObject(self, &SimpleImageAssociatedKeys.animatedImage)
        as? SimpleAnimatedImage
    }
    set {
      objc_setAssociatedObject(
        self,
        &SimpleImageAssociatedKeys.animatedImage,
        newValue,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
      )
    }
  }

  /// Whether this image is backed by a multi-frame animation.
  public var si_isAnimated: Bool { si_animatedImage?.isAnimated ?? false }
}
