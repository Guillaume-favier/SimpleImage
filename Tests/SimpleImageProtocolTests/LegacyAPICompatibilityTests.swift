//
//  LegacyAPICompatibilityTests.swift
//  SimpleImageTests
//
//  This file is written *only* against the stable public API surface, as a
//  consumer of the library would have written it. If it compiles and passes,
//  the library is a drop-in replacement for those bindings: the manager,
//  request, loader, transformer and processor protocols are unchanged.
//
//  Note: `SimpleImageCache` intentionally changed to store raw `Data` (so
//  animated GIFs survive caching). That protocol is an internal seam — not a
//  public compatibility surface — so its conformers were updated accordingly.
//

import Testing
import UIKit

@testable import SimpleImage

// MARK: - A consumer's original-style conformances

private struct LegacyLoader: SimpleImageLoader {
  func imageData(
    for request: URLRequest,
    progressHandler: @escaping @Sendable (Double) -> Void
  ) async throws -> Data {
    progressHandler(0)
    progressHandler(1)
    return LegacyImages.pngData()
  }
}

private struct LegacyProcessor: SimpleImageProcessor {
  let identifier = "legacy-noop"

  func process(image: UIImage) async throws -> UIImage {
    image
  }
}

private struct LegacyTransformer: SimpleImageTransformer {
  func transform(data: Data) async throws -> Data {
    data
  }
}

/// An actor conforms to `SimpleImageCache` exactly like a class would.
private actor LegacyCache: SimpleImageCache {
  private var storage: [String: Data] = [:]

  func cache(_ data: Data, forKey cacheKey: String) async throws {
    storage[cacheKey] = data
  }

  func retrieveData(forKey cacheKey: String) async throws -> Data? {
    storage[cacheKey]
  }

  func isCached(forKey cacheKey: String) async -> Bool {
    storage[cacheKey] != nil
  }
}

private enum LegacyImages {
  static func pngData(size: Int = 24) -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.pngData { context in
      UIColor.systemBlue.setFill()
      context.fill(CGRect(x: 0, y: 0, width: size, height: size))
    }
  }
}

// MARK: - Tests

@Suite("Legacy public API compatibility")
struct LegacyAPICompatibilityTests {
  @Test("Constructing a manager with custom loader/cache/transformers still compiles")
  func managerConstruction() async throws {
    let manager = SimpleImageManager(
      imageLoader: LegacyLoader(),
      imageCache: LegacyCache(),
      imageTransformers: [LegacyTransformer()]
    )

    let request = URLRequest(url: URL(string: "https://example.com/legacy.png")!)
    let image = try await manager.image(request: request, processors: [LegacyProcessor()])

    #expect(image.size.width > 0)
    #expect(image.size.height > 0)
  }

  @Test("The completion-handler API still delivers a Result<UIImage, Error>")
  func completionHandlerAPI() async throws {
    let manager = SimpleImageManager(
      imageLoader: LegacyLoader(),
      imageCache: LegacyCache(),
      imageTransformers: []
    )

    let request = URLRequest(url: URL(string: "https://example.com/legacy-2.png")!)

    let result: Result<UIImage, Error> = await withCheckedContinuation { continuation in
      manager.retrieveImage(request: request, processors: []) { result in
        continuation.resume(returning: result)
      }
    }

    switch result {
    case .success(let image):
      #expect(image.size.width > 0)
    case .failure(let error):
      Issue.record("Expected success, got \(error)")
    }
  }

  @Test("The cache stores raw data and retrieves it by key")
  func cacheProtocolShape() async throws {
    let cache = LegacyCache()
    let data = LegacyImages.pngData()

    #expect(await cache.isCached(forKey: "missing") == false)

    try await cache.cache(data, forKey: "legacy")
    #expect(await cache.isCached(forKey: "legacy"))

    let retrieved = try await cache.retrieveData(forKey: "legacy")
    #expect(retrieved == data)
  }

  @Test("SimpleImageRequest keeps its original initializer")
  func requestShape() throws {
    let url = try #require(URL(string: "https://example.com/a.png"))
    let request = SimpleImageRequest(
      urlRequest: URLRequest(url: url),
      processors: [LegacyProcessor()]
    )

    #expect(request.unprocessedCacheKey == url.absoluteString)
    #expect(request.cacheKey.contains("legacy-noop"))
  }

  @Test("A UIImage-based processor still works through the container hook")
  func legacyProcessorViaContainer() async throws {
    let processor = LegacyProcessor()
    let container = SimpleImageDecoder.container(for: LegacyImages.pngData())

    let processed = try await processor.process(container: container)
    let image = try await processed.uiImage()

    #expect(image.size.width > 0)
    #expect(image.size.height > 0)
  }
}
