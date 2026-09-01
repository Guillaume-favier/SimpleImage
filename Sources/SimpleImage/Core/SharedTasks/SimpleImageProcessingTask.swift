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
    completionHandler: @escaping @Sendable (SimpleImageSharedTask, Result<UIImage, Error>, String?) -> Void,
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
        
        self.finish(with: .success(image), cacheKey: imageRequest.cacheKey)
      } catch {
        self.finish(with: .failure(error), cacheKey: nil)
      }
    }
  }
}
