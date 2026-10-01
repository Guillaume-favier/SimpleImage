//
//  SimpleImageCache.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

public protocol SimpleImageCache: Sendable {
  func cache(_ data: Data, forKey cacheKey: String) async throws

  func retrieveData(forKey cacheKey: String) async throws -> Data?

  func isCached(forKey cacheKey: String) async -> Bool
}
