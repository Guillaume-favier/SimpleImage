//
//  GIF.playground
//
//  A self-contained playground that exercises the new GIF capabilities and the
//  backward-compatible behaviour. It generates a GIF in memory, so it needs no
//  assets and no network.
//
//  Before running: make sure the `SimpleImage` package is available to this
//  playground (see TUTORIAL.md ▸ "Running the playground"). Select an iOS
//  simulator in the toolbar, then press ⌘↩ to run.
//

import ImageIO
import PlaygroundSupport
import SimpleImage  // SimpleImageDecoder, SimpleAnimatedImage, si_* helpers
import SimpleImageUIKit  // SimpleImageAnimatedView
import UIKit
import UniformTypeIdentifiers

// MARK: - 1. Make a GIF so we have something to decode

/// Draws a solid hue with a white block that moves each frame.
/// Pure Core Graphics, so it's safe to call from any thread.
func makeFrame(index: Int, frameCount: Int, size: Int) -> CGImage? {
  guard
    let context = CGContext(
      data: nil,
      width: size,
      height: size,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else { return nil }

  let hue = CGFloat(index) / CGFloat(max(1, frameCount))
  context.setFillColor(UIColor(hue: hue, saturation: 0.9, brightness: 0.9, alpha: 1).cgColor)
  context.fill(CGRect(x: 0, y: 0, width: size, height: size))

  let blockSize = size / 4
  context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  context.fill(
    CGRect(
      x: (index * blockSize) % size,
      y: (size - blockSize) / 2,
      width: blockSize,
      height: blockSize
    ))

  return context.makeImage()
}

func makeAnimatedGIFData(frameCount: Int, size: Int, frameDuration: Double) -> Data {
  let data = NSMutableData()
  guard
    let destination = CGImageDestinationCreateWithData(
      data,
      UTType.gif.identifier as CFString,
      frameCount,
      nil
    )
  else { return data as Data }

  // 0 = loop forever.
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

let gifData = makeAnimatedGIFData(frameCount: 6, size: 120, frameDuration: 0.2)
print("Generated GIF:", gifData.count, "bytes")

// MARK: - 2. The new, animation-aware decoding

let image = SimpleImageDecoder.decode(data: gifData)!

print("isAnimated:            ", image.si_isAnimated)
print("frameCount:            ", image.si_animatedImage?.frameCount ?? 0)
print("loopCount (0 = forever):", image.si_animatedImage?.loopCount ?? -1)
print("totalDuration (s):     ", image.si_animatedImage?.totalDuration ?? 0)
print("source bytes preserved:", image.si_animatedImage?.data.count ?? 0)

// Frames are decoded on demand — nothing was decoded up front.
let animated = image.si_animatedImage!
print(
  "frame 0 == frame 1?    ", animated.image(at: 0)?.pngData() == animated.image(at: 1)?.pngData())

// MARK: - 3. Backward compatibility

// The old APIs behave exactly as before: `UIImage(data:)` gives a *still*.
let legacy = UIImage(data: gifData)!
print("legacy UIImage still?  ", !legacy.si_isAnimated)

// `SimpleImageDecoder.decode` still returns a plain UIImage, so it drops into
// existing code (e.g. `imageView.image = ...`).
let asPlainUIImage: UIImage = SimpleImageDecoder.decode(data: gifData)!
print("as plain UIImage size: ", asPlainUIImage.size)

// MARK: - 4. Play it for real

let animatedView = SimpleImageAnimatedView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
animatedView.contentMode = .scaleAspectFit
animatedView.backgroundColor = .black
animatedView.si_animatedImage = animated

PlaygroundPage.current.liveView = animatedView
PlaygroundPage.current.needsIndefiniteExecution = true

print("Playing on the live view — look at the assistant editor / live preview.")
