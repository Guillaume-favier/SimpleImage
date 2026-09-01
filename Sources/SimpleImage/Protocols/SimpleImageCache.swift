//
//  SimpleImageCache.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

public protocol SimpleImageCache: Sendable {
  func cacheImage(_ image: UIImage, forKey cacheKey: String) async throws
  
  func retrieveImage(forKey cacheKey: String) async throws -> UIImage?
  
  func imageIsCached(forKey cacheKey: String) async -> Bool
}
