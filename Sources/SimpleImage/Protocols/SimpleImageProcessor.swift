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
  // Default: decode → process(image:) → wrap. Drops animation unless overridden.
  public func process(container: ImageContainer) async throws -> ImageContainer {
    let image = try await container.uiImage()
    let processed = try await self.process(image: image)
    return StillImageContainer(image: processed)
  }
}
