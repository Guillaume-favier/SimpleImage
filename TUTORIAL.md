# Animated GIF support, changes & decisions

This branch adds first-class animated GIF support to `SimpleImage`. The old
pipeline decoded every image to a still `UIImage` and cached it by re-encoding
to PNG, which silently flattened GIFs to a single frame. This work keeps the
public API intact while fixing the cache and adding lazy frame playback.

## What changed

| Type | Description |
|---|---|
| `ImageContainer` | Protocol pairing an image's original bytes with a lazy `uiImage()` |
| `StillImageContainer` | `ImageContainer` for non-animated data |
| `GifContainer` | Typealias for `SimpleAnimatedImage`, the animated container |
| `SimpleAnimatedImage` | Lazy, bounded frame decoder (ImageIO + `NSCache`, 8 frames) |
| `SimpleImageDecoder` | Animation-aware entry point (`container(for:)`, `decode(data:)`) |
| `SimpleImageAnimatedView` | `UIImageView` subclass that plays frames via `CADisplayLink` |
| `DataMemoryCache` | In-memory LRU for raw bytes (cost = byte count) |
| `SimpleImageCache` | Protocol now stores `Data`, not `UIImage` |

## Key decisions

1. **The cache stores bytes, not `UIImage`.** Decoding happens at delivery, so
   GIFs survive a cache round-trip and memory accounting is trivially correct
   (`data.count`). The public `retrieveImage` API is unchanged, only the
   `SimpleImageCache` protocol changed, which is an internal seam rather than a
   public compatibility surface.
2. **`ImageContainer` is the seam.** It carries the original compressed bytes
   plus a lazy decoder, so the pipeline only materialises a `UIImage` at the
   last moment.
3. **Processors stay `UIImage`-first.** `process(image:)` remains the protocol
   requirement; a default `process(container:)` bridges it. GIF-aware processors
   override `process(container:)`. Existing processors (e.g. Kingfisher ports)
   keep working unchanged.
4. **`GifContainer` is a typealias, not a rename.** `SimpleAnimatedImage` is
   more general (any multi-frame ImageIO format) and already public/tested.
5. **Loop count follows the GIF spec.** `0` = infinite; `N` = N additional loops
   after the first play.

## Backward compatibility

- `SimpleImageManager.retrieveImage(...)` → `Result<UIImage, Error>`: unchanged.
- `SimpleImageProcessor.process(image:)`: unchanged.
- `UIImage(data:)`: still returns a still first frame.
- `SimpleImageCache` protocol: **changed** to store `Data` (intentional).
- Removed: `si_sourceData` / `si_encodedData`, obsolete now that the cache owns
  the bytes.

## Verification

```sh
xcodebuild -scheme SimpleImage-Package \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

See `../SimpleImageDemo/README.md` for the side-by-side demo (legacy still vs
animated playback, cache round-trip, and the performance harness).
