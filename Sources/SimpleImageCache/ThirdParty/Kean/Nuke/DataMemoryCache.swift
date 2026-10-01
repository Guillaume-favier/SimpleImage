// The MIT License (MIT)
//
// Copyright (c) 2015-2026 Alexander Grebenyuk (github.com/kean).

import Foundation

/// An LRU in-memory cache for raw image bytes.
///
/// The `Data` counterpart to `ImageCache`. Storing compressed bytes (rather
/// than decoded `UIImage`s) lets animated GIFs survive a memory-cache
/// round-trip, and keeps cost accounting correct (`data.count` bytes).
public final class DataMemoryCache: Sendable {
    private let impl: Cache<String, Data>

    /// The maximum total cost that the cache can hold.
    public var costLimit: Int {
        get { impl.conf.costLimit }
        set { impl.conf.costLimit = newValue }
    }

    /// The maximum number of items that the cache can hold.
    public var countLimit: Int {
        get { impl.conf.countLimit }
        set { impl.conf.countLimit = newValue }
    }

    /// The total number of items in the cache.
    public var totalCount: Int { impl.totalCount }

    /// The total cost of items in the cache.
    public var totalCost: Int { impl.totalCost }

    /// Creates a cache with the given limits.
    /// - parameter costLimit: The cost limit in bytes. Defaults to 10% of the
    /// device's physical memory, capped at 512 MB.
    /// - parameter countLimit: `Int.max` by default.
    public init(costLimit: Int = DataMemoryCache.defaultCostLimit, countLimit: Int = Int.max) {
        impl = Cache(costLimit: costLimit, countLimit: countLimit)
    }

    public static var defaultCostLimit: Int {
        let calculated = Int(Double(ProcessInfo.processInfo.physicalMemory) * 0.1)
        return min(calculated, 536_870_912)  // 512 MB
    }

    public subscript(key: String) -> Data? {
        get { impl.value(forKey: key) }
        set {
            if let data = newValue {
                impl.set(data, forKey: key, cost: data.count)
            } else {
                impl.removeValue(forKey: key)
            }
        }
    }

    /// Removes all cached data.
    public func removeAll() {
        impl.removeAllCachedValues()
    }
}
