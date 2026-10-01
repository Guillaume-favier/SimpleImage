// The MIT License (MIT)
//
// Copyright (c) 2015-2026 Alexander Grebenyuk (github.com/kean).

import Foundation

public final class DataMemoryCache: Sendable {
    private let impl: Cache<String, Data>

    public var costLimit: Int {
        get { impl.conf.costLimit }
        set { impl.conf.costLimit = newValue }
    }

    public var countLimit: Int {
        get { impl.conf.countLimit }
        set { impl.conf.countLimit = newValue }
    }

    public var ttl: TimeInterval? {
        get { impl.conf.ttl }
        set { impl.conf.ttl = newValue }
    }

    public var entryCostLimit: Double {
        get { impl.conf.entryCostLimit }
        set { impl.conf.entryCostLimit = newValue }
    }

    public var totalCount: Int { impl.totalCount }

    public var totalCost: Int { impl.totalCost }

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

    public func removeAll() {
        impl.removeAllCachedValues()
    }

    public func trim(toCost limit: Int) {
        impl.trim(toCost: limit)
    }

    public func trim(toCount limit: Int) {
        impl.trim(toCount: limit)
    }
}
