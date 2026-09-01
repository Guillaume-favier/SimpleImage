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
    completionHandler: @escaping @Sendable (SimpleImageSharedTask, Result<UIImage, Error>, String?) -> Void,
  ) {
    super.init(request: imageRequest.urlRequest, completionHandler: completionHandler)
    
    self.state = .waiting { [weak self] in
      guard let self else { return }
      
      do {
        if let image = try await imageCache.retrieveImage(forKey: imageRequest.unprocessedCacheKey) {
          self.finish(with: .success(image), cacheKey: nil)
        } else {
          var imageData = try await imageLoader.imageData(for: imageRequest.urlRequest)
          
          for imageTransformer in imageTransformers {
            try Task.checkCancellation()
            imageData = try await imageTransformer.transform(data: imageData)
          }
          
          guard var finalImage = UIImage(data: imageData) else {
            throw SimpleImageError.invalidImageData
          }
          
          self.finish(with: .success(finalImage), cacheKey: imageRequest.unprocessedCacheKey)
        }
      } catch {
        self.finish(with: .failure(error), cacheKey: nil)
      }
    }
  }
}
