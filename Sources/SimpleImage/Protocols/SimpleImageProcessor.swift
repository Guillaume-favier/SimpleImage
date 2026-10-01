//
//  SimpleImageProcessor.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

public protocol SimpleImageProcessor: Sendable {
  var identifier: String { get }
  func process(image: UIImage) async throws -> UIImage
}

extension SimpleImageProcessor {
  /// GIF/container-aware processing hook.
  ///
  /// The default implementation decodes the container's representative image,
  /// runs `process(image:)`, and wraps the result back into a
  /// ``StillImageContainer`` — which drops animation. Processors that want to
  /// work with animated content (e.g. inspecting or transforming a
  /// ``GifContainer`` frame by frame) can override this method.
  public func process(container: ImageContainer) async throws -> ImageContainer {
    let image = try await container.uiImage()
    let processed = try await self.process(image: image)
    return StillImageContainer(image: processed)
  }
}
