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
    completionHandler:
      @escaping @Sendable (SimpleImageSharedTask, Result<ImageContainer, Error>) -> Void,
  ) {
    super.init(request: imageRequest.urlRequest, completionHandler: completionHandler)

    self.state = .waiting { [weak self] in
      guard let self else { return }

      do {
        if let data = try await imageCache.retrieveData(forKey: imageRequest.cacheKey) {
          self.finish(with: .success(SimpleImageDecoder.container(for: data)))
        } else {
          self.finish(with: .failure(SimpleImageError.cacheMiss(cacheKey: imageRequest.cacheKey)))
        }
      } catch {
        self.finish(with: .failure(error))
      }
    }
  }
}
