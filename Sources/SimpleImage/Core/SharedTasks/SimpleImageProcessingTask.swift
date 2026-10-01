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
    container: ImageContainer,
    imageCache: SimpleImageCache,
    completionHandler:
      @escaping @Sendable (SimpleImageSharedTask, Result<ImageContainer, Error>) -> Void,
  ) {
    super.init(request: imageRequest.urlRequest, completionHandler: completionHandler)

    self.state = .waiting { [weak self] in
      guard let self else { return }

      do {
        var container = container

        for processor in imageRequest.processors {
          try Task.checkCancellation()
          container = try await processor.process(container: container)
        }

        try await imageCache.cache(container.data, forKey: imageRequest.cacheKey)

        self.finish(with: .success(container))
      } catch {
        self.finish(with: .failure(error))
      }
    }
  }
}
