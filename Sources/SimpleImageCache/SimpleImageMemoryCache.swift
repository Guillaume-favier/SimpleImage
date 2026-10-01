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
  public let dataCache: DataMemoryCache

  public init(dataCache: DataMemoryCache) {
    self.dataCache = dataCache
  }

  public func cache(_ data: Data, forKey cacheKey: String) async throws {
    self.dataCache[cacheKey] = data
  }

  public func retrieveData(forKey cacheKey: String) async throws -> Data? {
    return self.dataCache[cacheKey]
  }

  public func isCached(forKey cacheKey: String) async -> Bool {
    return self.dataCache[cacheKey] != nil
  }
}
