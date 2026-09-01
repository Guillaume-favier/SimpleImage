//
//  SimpleImageCompositeCache.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 01/09/2026.
//

import Foundation
import SimpleImage
import UIKit

final class SimpleImageCompositeCache: SimpleImageCache {
  let memoryCache: SimpleImageMemoryCache
  let diskCache: SimpleImageDiskCache
  
  init(memoryCache: SimpleImageMemoryCache, diskCache: SimpleImageDiskCache) {
    self.memoryCache = memoryCache
    self.diskCache = diskCache
  }
  
  func cacheImage(_ image: UIImage, forKey cacheKey: String) async throws {
    async let mem = self.memoryCache.cacheImage(image, forKey: cacheKey)
    async let disk = self.diskCache.cacheImage(image, forKey: cacheKey)
    
    _ = try await (mem, disk)
  }
  
  func retrieveImage(forKey cacheKey: String) async throws -> UIImage? {
    if let image = try await self.memoryCache.retrieveImage(forKey: cacheKey) {
      return image
    }
    
    if let image = try await self.diskCache.retrieveImage(forKey: cacheKey) {
      return image
    }
    
    return nil
  }
  
  func imageIsCached(forKey cacheKey: String) async -> Bool {
    if await self.memoryCache.imageIsCached(forKey: cacheKey) {
      return true
    }
    
    if await self.diskCache.imageIsCached(forKey: cacheKey) {
      return true
    }
    
    return false
  }
}
