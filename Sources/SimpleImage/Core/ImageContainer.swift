//
//  ImageContainer.swift
//  SimpleImage
//

import Foundation
import UIKit

public protocol ImageContainer: Sendable {
    var data: Data { get }
    func uiImage() async throws -> UIImage
}

public typealias GifContainer = SimpleAnimatedImage

public struct StillImageContainer: ImageContainer {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    // PNG first: lossless. JPEG is the fallback.
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
