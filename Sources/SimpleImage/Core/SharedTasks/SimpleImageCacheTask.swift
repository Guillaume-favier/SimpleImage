//
//  SimpleImageCacheTask.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//


import Foundation
import UIKit

final class SimpleImageCacheTask: SimpleImageSharedTask, @unchecked Sendable {
  init(
    imageRequest: SimpleImageRequest,
    imageCache: SimpleImageCache,
    completionHandler: @escaping @Sendable (SimpleImageSharedTask, Result<UIImage, Error>, String?) -> Void,
  ) {
    super.init(request: imageRequest.urlRequest, completionHandler: completionHandler)
    
    self.state = .waiting { [weak self] in
      guard let self else { return }
      
      do {
        if let image = try await imageCache.retrieveImage(forKey: imageRequest.cacheKey) {
          self.finish(with: .success(image), cacheKey: nil)
        } else {
          self.finish(with: .failure(SimpleImageError.cacheMiss(cacheKey: imageRequest.cacheKey)), cacheKey: nil)
        }
      } catch {
        self.finish(with: .failure(error), cacheKey: nil)
      }
    }
  }
}
