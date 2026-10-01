//
//  SimpleImageProcessingTask.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

final class SimpleImageProcessingTask: SimpleImageSharedTask, @unchecked Sendable {
  init(
    imageRequest: SimpleImageRequest,
    image: UIImage,
    imageCache: SimpleImageCache,
    completionHandler:
      @escaping @Sendable (SimpleImageSharedTask, Result<UIImage, Error>, String?) -> Void,
  ) {
    super.init(request: imageRequest.urlRequest, completionHandler: completionHandler)

    self.state = .waiting { [weak self] in
      guard let self else { return }

      do {
        var image = image

        for processor in imageRequest.processors {
          try Task.checkCancellation()
          image = try await processor.process(image: image)
        }

        // Processors return a decoded UIImage; re-encode for caching.
        if let data = image.pngData() {
          try await imageCache.cache(data, forKey: imageRequest.cacheKey)
        }

        self.finish(with: .success(image), cacheKey: nil)
      } catch {
        self.finish(with: .failure(error), cacheKey: nil)
      }
    }
  }
}
