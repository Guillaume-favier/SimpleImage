//
//  ImageContainer.swift
//  SimpleImage
//

import Foundation
import UIKit

/// A container that pairs an image's original, compressed bytes with the
/// ability to produce a `UIImage` from them on demand.
///
/// This is the seam that lets the cache store **bytes** (so animated GIFs and
/// their compression survive a round-trip) while the rest of the pipeline only
/// materialises a `UIImage` at the very last moment.
public protocol ImageContainer: Sendable {
    /// The original, compressed image bytes.
    var data: Data { get }

    /// Decodes and returns a `UIImage`.
    ///
    /// For animated content the returned image is a still representative (first)
    /// frame with `si_animatedImage` attached, so callers that want playback can
    /// detect and drive it themselves.
    func uiImage() async throws -> UIImage
}

/// The animation-aware container. An alias so the concept is self-describing:
/// it's what backs animated GIFs (and any other multi-frame format ImageIO can
/// read) in the pipeline.
public typealias GifContainer = SimpleAnimatedImage

/// A container for non-animated image data.
public struct StillImageContainer: ImageContainer {
    public let data: Data

    /// Wraps already-encoded bytes.
    public init(data: Data) {
        self.data = data
    }

    /// Wraps an already-decoded image by re-encoding it.
    ///
    /// Used by processors that return a `UIImage` (which carries no original
    /// bytes). PNG is preferred because it is lossless; JPEG is the fallback.
    public init(image: UIImage) {
        self.data = image.pngData() ?? image.jpegData(compressionQuality: 0.9) ?? Data()
    }

    public func uiImage() async throws -> UIImage {
        guard let image = UIImage(data: data) else {
            throw SimpleImageError.invalidImageData
        }
        return image
    }
}
