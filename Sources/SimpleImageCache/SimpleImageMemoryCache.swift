//
//  SimpleImageMemoryCache.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import SimpleImage
import UIKit

public final class SimpleImageMemoryCache: SimpleImageCache {
  public let imageCache: ImageCache
  
  public init(imageCache: ImageCache) {
    self.imageCache = imageCache
  }
  
  public func cacheImage(_ image: UIImage, forKey cacheKey: String) async throws {
    self.imageCache[cacheKey] = image
  }
  
  public func retrieveImage(forKey cacheKey: String) async throws -> UIImage? {
    return self.imageCache[cacheKey]
  }
  
  public func imageIsCached(forKey cacheKey: String) async -> Bool {
    return self.imageCache[cacheKey] != nil
  }
}
