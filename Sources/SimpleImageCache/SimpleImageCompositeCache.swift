//
//  SimpleImageCompositeCache.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 01/09/2026.
//

import Foundation
import SimpleImage
import UIKit

public final class SimpleImageCompositeCache: SimpleImageCache {
  let memoryCache: SimpleImageMemoryCache
  let diskCache: SimpleImageDiskCache

  public init(memoryCache: SimpleImageMemoryCache, diskCache: SimpleImageDiskCache) {
    self.memoryCache = memoryCache
    self.diskCache = diskCache
  }

  public func cache(_ data: Data, forKey cacheKey: String) async throws {
    async let mem = self.memoryCache.cache(data, forKey: cacheKey)
    async let disk = self.diskCache.cache(data, forKey: cacheKey)

    _ = try await (mem, disk)
  }

  public func retrieveData(forKey cacheKey: String) async throws -> Data? {
    if let data = try await self.memoryCache.retrieveData(forKey: cacheKey) {
      return data
    }

    if let data = try await self.diskCache.retrieveData(forKey: cacheKey) {
      try await self.memoryCache.cache(data, forKey: cacheKey)
      return data
    }

    return nil
  }

  public func isCached(forKey cacheKey: String) async -> Bool {
    if await self.memoryCache.isCached(forKey: cacheKey) {
      return true
    }

    if await self.diskCache.isCached(forKey: cacheKey) {
      return true
    }

    return false
  }
}
