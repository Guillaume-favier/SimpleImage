//
//  SimpleImageDiskCache.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import SimpleImage
import UIKit

public final class SimpleImageDiskCache: SimpleImageCache {
  public let dataCache: DataCache
  
  public init(dataCache: DataCache) {
    self.dataCache = dataCache
  }
  
  public func cacheImage(_ image: UIImage, forKey cacheKey: String) async throws {
    guard let data = image.pngData() else { return }
    self.dataCache.storeData(data, for: cacheKey)
  }
  
  public func retrieveImage(forKey cacheKey: String) async throws -> UIImage? {
    guard let data = self.dataCache.cachedData(for: cacheKey) else {
      return nil
    }
    
    return UIImage(data: data)
  }
  
  public func imageIsCached(forKey cacheKey: String) async -> Bool {
    self.dataCache.containsData(for: cacheKey)
  }
}
