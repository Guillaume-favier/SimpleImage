//
//  SimpleImageDiskCache.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import SimpleImage

public final class SimpleImageDiskCache: SimpleImageCache {
  public let dataCache: DataCache

  public init(dataCache: DataCache) {
    self.dataCache = dataCache
  }

  public func cache(_ data: Data, forKey cacheKey: String) async throws {
    self.dataCache.storeData(data, for: cacheKey)
  }

  public func retrieveData(forKey cacheKey: String) async throws -> Data? {
    self.dataCache.cachedData(for: cacheKey)
  }

  public func isCached(forKey cacheKey: String) async -> Bool {
    self.dataCache.containsData(for: cacheKey)
  }
}
