//
//  SimpleImageDownloadTask.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

final class SimpleImageDownloadTask: SimpleImageSharedTask, @unchecked Sendable {
  init(
    imageRequest: SimpleImageRequest,
    imageLoader: SimpleImageLoader,
    imageTransformers: [SimpleImageTransformer],
    imageCache: SimpleImageCache,
    completionHandler:
      @escaping @Sendable (SimpleImageSharedTask, Result<UIImage, Error>, String?) -> Void,
  ) {
    super.init(request: imageRequest.urlRequest, completionHandler: completionHandler)

    self.state = .waiting { [weak self] in
      guard let self else { return }

      do {
        let data: Data
        if let cached = try await imageCache.retrieveData(forKey: imageRequest.unprocessedCacheKey)
        {
          data = cached
        } else {
          var imageData = try await imageLoader.imageData(
            for: imageRequest.urlRequest,
            progressHandler: { [weak self] in self?.reportProgress($0) })

          for imageTransformer in imageTransformers {
            try Task.checkCancellation()
            imageData = try await imageTransformer.transform(data: imageData)
          }

          try Task.checkCancellation()
          // Cache the raw bytes so animations survive the round-trip.
          try await imageCache.cache(imageData, forKey: imageRequest.unprocessedCacheKey)
          data = imageData
        }

        guard let finalImage = UIImage(data: data) else {
          throw SimpleImageError.invalidImageData
        }

        self.finish(with: .success(finalImage), cacheKey: nil)
      } catch {
        self.finish(with: .failure(error), cacheKey: nil)
      }
    }
  }
}
