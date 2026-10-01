//
//  SimpleImageGIFTests.swift
//  SimpleImageTests
//
//  Tests for the animation-aware decoder and backward compatibility.
//  Run with Product ▸ Test (⌘U) in Xcode, or `swift test` on an iOS-capable setup.
//

import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers

@testable import SimpleImage

// MARK: - Fixtures

/// Builds an in-memory animated GIF so the tests don't need a bundled asset.
private func makeAnimatedGIFData(frameCount: Int, size: Int, frameDuration: Double) -> Data {
  let data = NSMutableData()
  guard
    let destination = CGImageDestinationCreateWithData(
      data,
      UTType.gif.identifier as CFString,
      frameCount,
      nil
    )
  else {
    return data as Data
  }

  // Loop forever.
  CGImageDestinationSetProperties(
    destination,
    [
      kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]
    ] as CFDictionary)

  let frameProperties: [CFString: Any] = [
    kCGImagePropertyGIFDictionary: [
      kCGImagePropertyGIFDelayTime: frameDuration,
      kCGImagePropertyGIFUnclampedDelayTime: frameDuration,
    ]
  ]

  for index in 0..<frameCount {
    guard let frame = makeFrame(index: index, frameCount: frameCount, size: size) else { continue }
    CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
  }

  CGImageDestinationFinalize(destination)
  return data as Data
}

/// Draws a solid hue with a white block that moves each frame, so frames differ.
private func makeFrame(index: Int, frameCount: Int, size: Int) -> CGImage? {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  guard
    let context = CGContext(
      data: nil,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else {
    return nil
  }

  let hue = CGFloat(index) / CGFloat(max(1, frameCount))
  context.setFillColor(UIColor(hue: hue, saturation: 1, brightness: 1, alpha: 1).cgColor)
  context.fill(CGRect(x: 0, y: 0, width: size, height: size))

  let blockSize = size / 4
  context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  context.fill(
    CGRect(
      x: (index * blockSize) % size, y: (size - blockSize) / 2, width: blockSize, height: blockSize)
  )

  return context.makeImage()
}

/// A plain, non-animated PNG.
private func makeStaticPNGData(size: Int = 32) -> Data {
  let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
  return renderer.pngData { context in
    UIColor.systemTeal.setFill()
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
  }
}

// MARK: - Tests

@Suite("Animated image decoding")
struct SimpleImageAnimatedDecodingTests {
  @Test("A multi-frame GIF is detected and decoded as animated")
  func animatedGIFIsDetected() throws {
    let gifData = makeAnimatedGIFData(frameCount: 3, size: 64, frameDuration: 0.2)

    #expect(SimpleImageDecoder.isAnimated(data: gifData))

    let image = try #require(SimpleImageDecoder.decode(data: gifData))
    #expect(image.si_isAnimated)

    let animated = try #require(image.si_animatedImage)
    #expect(animated.frameCount == 3)
    #expect(animated.loopCount == 0)
    #expect(abs(animated.totalDuration - 0.6) < 0.001)
  }

  @Test("Frames are decoded lazily and are actually distinct")
  func framesAreDistinct() throws {
    let gifData = makeAnimatedGIFData(frameCount: 3, size: 64, frameDuration: 0.2)
    let image = try #require(SimpleImageDecoder.decode(data: gifData))
    let animated = try #require(image.si_animatedImage)

    let first = try #require(animated.image(at: 0)).pngData()
    let second = try #require(animated.image(at: 1)).pngData()

    #expect(first != second)
    #expect(animated.image(at: 99) != nil)  // index wraps around
  }

  @Test("A static image stays static")
  func staticImageIsNotAnimated() throws {
    let pngData = makeStaticPNGData()

    #expect(!SimpleImageDecoder.isAnimated(data: pngData))

    let image = try #require(SimpleImageDecoder.decode(data: pngData))
    #expect(!image.si_isAnimated)
    #expect(image.si_animatedImage == nil)
  }
}

@Suite("Backward compatibility")
struct SimpleImageBackwardCompatibilityTests {
  @Test("Legacy UIImage(data:) still returns a still first frame")
  func legacyInitializerStillReturnsStill() throws {
    let gifData = makeAnimatedGIFData(frameCount: 3, size: 64, frameDuration: 0.2)

    // This is the pre-existing behaviour: no animation, first frame only.
    let legacy = try #require(UIImage(data: gifData))
    #expect(!legacy.si_isAnimated)
    #expect(legacy.si_animatedImage == nil)
  }

  @Test("The decoder returns a UIImage so existing call sites keep working")
  func decoderReturnsUIImage() throws {
    let gifData = makeAnimatedGIFData(frameCount: 2, size: 32, frameDuration: 0.1)

    // Assigning to `UIImage` is exactly what the old pipeline did.
    let image: UIImage = try #require(SimpleImageDecoder.decode(data: gifData))
    #expect(image.size.width > 0)
    #expect(image.size.height > 0)
  }

  @Test("Original bytes are preserved through the container for caching")
  func sourceDataIsPreserved() throws {
    let gifData = makeAnimatedGIFData(frameCount: 4, size: 48, frameDuration: 0.1)

    let container = SimpleImageDecoder.container(for: gifData)
    #expect(container.data == gifData)

    // Animated data decodes to the animation-aware container.
    let animated = try #require(container as? SimpleAnimatedImage)
    #expect(animated.frameCount == 4)

    // Re-decoding the preserved bytes yields an animated image again.
    let roundTripped = try #require(SimpleImageDecoder.decode(data: container.data))
    #expect(roundTripped.si_isAnimated)
    #expect(roundTripped.si_animatedImage?.frameCount == 4)
  }

  @Test("A still image decodes to a still container")
  func stillImageProducesStillContainer() async throws {
    let pngData = makeStaticPNGData()

    let container = SimpleImageDecoder.container(for: pngData)
    #expect(container is StillImageContainer)

    let image = try #require(try await container.uiImage())
    #expect(!image.si_isAnimated)
    #expect(image.si_animatedImage == nil)
  }
}
