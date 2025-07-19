import Foundation
import UIKit

// MARK: - Cache Configuration
struct CacheConfiguration {
    let memoryCapacity: Int
    let diskCapacity: Int
    let maxAge: TimeInterval
    let cleanupInterval: TimeInterval
    let compressionEnabled: Bool
    let encryptionEnabled: Bool
    
    static let `default` = CacheConfiguration(
        memoryCapacity: 50 * 1024 * 1024,  // 50 MB
        diskCapacity: 200 * 1024 * 1024,   // 200 MB
        maxAge: 24 * 60 * 60,              // 24 hours
        cleanupInterval: 60 * 60,          // 1 hour
        compressionEnabled: true,
        encryptionEnabled: false
    )
    
    static let aggressive = CacheConfiguration(
        memoryCapacity: 100 * 1024 * 1024, // 100 MB
        diskCapacity: 500 * 1024 * 1024,   // 500 MB
        maxAge: 7 * 24 * 60 * 60,          // 7 days
        cleanupInterval: 30 * 60,          // 30 minutes
        compressionEnabled: true,
        encryptionEnabled: true
    )
    
    static let minimal = CacheConfiguration(
        memoryCapacity: 10 * 1024 * 1024,  // 10 MB
        diskCapacity: 50 * 1024 * 1024,    // 50 MB
        maxAge: 60 * 60,                   // 1 hour
        cleanupInterval: 10 * 60,          // 10 minutes
        compressionEnabled: false,
        encryptionEnabled: false
    )
}

// MARK: - Cache Entry
class CacheEntry: Codable {
    let key: String
    let data: Data
    let timestamp: Date
    let expirationDate: Date
    let metadata: [String: String]
    let accessCount: Int
    let lastAccessDate: Date
    
    init(key: String, data: Data, maxAge: TimeInterval, metadata: [String: String] = [:]) {
        self.key = key
        self.data = data
        self.timestamp = Date()
        self.expirationDate = Date().addingTimeInterval(maxAge)
        self.metadata = metadata
        self.accessCount = 0
        self.lastAccessDate = Date()
    }
    
    private enum CodingKeys: String, CodingKey {
        case key, data, timestamp, expirationDate, metadata, accessCount, lastAccessDate
    }
    
    var isExpired: Bool {
        return Date() > expirationDate
    }
    
    var age: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
    
    func accessed() -> CacheEntry {
        let newEntry = CacheEntry(key: key, data: data, maxAge: expirationDate.timeIntervalSince(Date()), metadata: metadata)
        return newEntry
    }
}

// MARK: - Cache Strategy
enum CacheStrategy {
    case lru           // Least Recently Used
    case lfu           // Least Frequently Used
    case fifo          // First In, First Out
    case ttl           // Time To Live
    case adaptive      // Adaptive based on usage patterns
    
    func shouldEvict(entries: [CacheEntry], newEntry: CacheEntry) -> [String] {
        switch self {
        case .lru:
            return entries.sorted { $0.lastAccessDate < $1.lastAccessDate }.prefix(1).map { $0.key }
        case .lfu:
            return entries.sorted { $0.accessCount < $1.accessCount }.prefix(1).map { $0.key }
        case .fifo:
            return entries.sorted { $0.timestamp < $1.timestamp }.prefix(1).map { $0.key }
        case .ttl:
            return entries.filter { $0.isExpired }.map { $0.key }
        case .adaptive:
            // Combine multiple factors for adaptive eviction
            let expiredKeys = entries.filter { $0.isExpired }.map { $0.key }
            if !expiredKeys.isEmpty {
                return expiredKeys
            }
            
            // If no expired entries, use LRU
            return entries.sorted { $0.lastAccessDate < $1.lastAccessDate }.prefix(1).map { $0.key }
        }
    }
}

// MARK: - Cache Level
enum CacheLevel {
    case memory
    case disk
    case distributed
    
    var priority: Int {
        switch self {
        case .memory: return 1
        case .disk: return 2
        case .distributed: return 3
        }
    }
}

// MARK: - Cache Hit/Miss Statistics
class CacheStatistics {
    private var hits: Int = 0
    private var misses: Int = 0
    private var evictions: Int = 0
    private var writes: Int = 0
    private let lock = NSLock()
    
    func recordHit() {
        lock.lock()
        hits += 1
        lock.unlock()
    }
    
    func recordMiss() {
        lock.lock()
        misses += 1
        lock.unlock()
    }
    
    func recordEviction() {
        lock.lock()
        evictions += 1
        lock.unlock()
    }
    
    func recordWrite() {
        lock.lock()
        writes += 1
        lock.unlock()
    }
    
    var hitRate: Double {
        lock.lock()
        defer { lock.unlock() }
        let total = hits + misses
        return total > 0 ? Double(hits) / Double(total) : 0.0
    }
    
    var metrics: (hits: Int, misses: Int, evictions: Int, writes: Int, hitRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        return (hits, misses, evictions, writes, hitRate)
    }
    
    func reset() {
        lock.lock()
        hits = 0
        misses = 0
        evictions = 0
        writes = 0
        lock.unlock()
    }
}

// MARK: - Multi-Level Cache
class MultiLevelCache {
    private let memoryCache: NSCache<NSString, CacheEntry>
    private let diskCache: DiskCache
    private let configuration: CacheConfiguration
    private let strategy: CacheStrategy
    private let statistics: CacheStatistics
    private let logger: LoggingService
    private let queue = DispatchQueue(label: "com.roomfinder.cache", qos: .utility)
    private var cleanupTimer: Timer?
    
    init(configuration: CacheConfiguration = .default, strategy: CacheStrategy = .adaptive) {
        self.configuration = configuration
        self.strategy = strategy
        self.statistics = CacheStatistics()
        self.logger = LoggingService.shared
        
        // Setup memory cache
        self.memoryCache = NSCache<NSString, CacheEntry>()
        self.memoryCache.countLimit = configuration.memoryCapacity / 1024 // Rough estimate
        self.memoryCache.totalCostLimit = configuration.memoryCapacity
        
        // Setup disk cache
        self.diskCache = DiskCache(
            capacity: configuration.diskCapacity,
            maxAge: configuration.maxAge,
            compressionEnabled: configuration.compressionEnabled,
            encryptionEnabled: configuration.encryptionEnabled
        )
        
        // Setup cleanup timer
        setupCleanupTimer()
        
        // Listen for memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        cleanupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Cache Operations
    
    func set<T: Codable>(key: String, value: T, maxAge: TimeInterval? = nil, metadata: [String: String] = [:]) {
        let actualMaxAge = maxAge ?? configuration.maxAge
        
        queue.async {
            do {
                let data = try JSONEncoder().encode(value)
                let entry = CacheEntry(key: key, data: data, maxAge: actualMaxAge, metadata: metadata)
                
                // Store in memory cache
                self.memoryCache.setObject(entry, forKey: key as NSString, cost: data.count)
                
                // Store in disk cache
                try self.diskCache.store(entry: entry)
                
                self.statistics.recordWrite()
                
                self.logger.debug("Cached object for key: \(key)", category: .cache, metadata: [
                    "size": data.count,
                    "maxAge": actualMaxAge,
                    "level": "multi"
                ])
                
            } catch {
                self.logger.error("Failed to cache object for key: \(key)", category: .cache, metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    func get<T: Codable>(key: String, type: T.Type) async -> T? {
        return await withCheckedContinuation { continuation in
            queue.async {
                // Try memory cache first
                if let entry = self.memoryCache.object(forKey: key as NSString) {
                    if !entry.isExpired {
                        do {
                            let value = try JSONDecoder().decode(type, from: entry.data)
                            self.statistics.recordHit()
                            
                            self.logger.debug("Cache hit (memory) for key: \(key)", category: .cache, metadata: [
                                "level": "memory",
                                "age": entry.age
                            ])
                            
                            continuation.resume(returning: value)
                            return
                        } catch {
                            self.logger.error("Failed to decode cached object from memory: \(key)", category: .cache)
                        }
                    } else {
                        // Remove expired entry
                        self.memoryCache.removeObject(forKey: key as NSString)
                    }
                }
                
                // Try disk cache
                do {
                    if let entry = try self.diskCache.retrieve(key: key) {
                        if !entry.isExpired {
                            let value = try JSONDecoder().decode(type, from: entry.data)
                            
                            // Promote to memory cache
                            self.memoryCache.setObject(entry, forKey: key as NSString, cost: entry.data.count)
                            
                            self.statistics.recordHit()
                            
                            self.logger.debug("Cache hit (disk) for key: \(key)", category: .cache, metadata: [
                                "level": "disk",
                                "age": entry.age
                            ])
                            
                            continuation.resume(returning: value)
                            return
                        } else {
                            // Remove expired entry
                            try self.diskCache.remove(key: key)
                        }
                    }
                } catch {
                    self.logger.error("Failed to retrieve from disk cache: \(key)", category: .cache)
                }
                
                // Cache miss
                self.statistics.recordMiss()
                self.logger.debug("Cache miss for key: \(key)", category: .cache)
                continuation.resume(returning: nil)
            }
        }
    }
    
    func remove(key: String) {
        queue.async {
            self.memoryCache.removeObject(forKey: key as NSString)
            
            do {
                try self.diskCache.remove(key: key)
                self.logger.debug("Removed cache entry for key: \(key)", category: .cache)
            } catch {
                self.logger.error("Failed to remove cache entry: \(key)", category: .cache)
            }
        }
    }
    
    func clear() {
        queue.async {
            self.memoryCache.removeAllObjects()
            
            do {
                try self.diskCache.clear()
                self.statistics.reset()
                self.logger.info("Cleared all cache entries", category: .cache)
            } catch {
                self.logger.error("Failed to clear cache", category: .cache)
            }
        }
    }
    
    // MARK: - Cache with Expiration
    
    func setWithExpiration<T: Codable>(key: String, value: T, expirationDate: Date, metadata: [String: String] = [:]) {
        let maxAge = expirationDate.timeIntervalSince(Date())
        set(key: key, value: value, maxAge: maxAge, metadata: metadata)
    }
    
    // MARK: - Cache Warming
    
    func warm(keys: [String]) async {
        logger.info("Starting cache warming for \(keys.count) keys", category: .cache)
        
        for key in keys {
            // This would typically involve pre-loading data
            // Implementation depends on your data sources
            logger.debug("Warming cache for key: \(key)", category: .cache)
        }
    }
    
    // MARK: - Statistics and Monitoring
    
    func getStatistics() -> (hits: Int, misses: Int, evictions: Int, writes: Int, hitRate: Double) {
        return statistics.metrics
    }
    
    func getCacheSize() -> (memorySize: Int, diskSize: Int) {
        return (
            memoryCache.totalCostLimit,
            diskCache.getCurrentSize()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: configuration.cleanupInterval, repeats: true) { _ in
            self.performCleanup()
        }
    }
    
    private func performCleanup() {
        queue.async {
            self.logger.debug("Starting cache cleanup", category: .cache)
            
            // Cleanup memory cache (automatic via NSCache)
            
            // Cleanup disk cache
            do {
                let removedCount = try self.diskCache.cleanup()
                if removedCount > 0 {
                    self.logger.info("Cleaned up \(removedCount) expired cache entries", category: .cache)
                }
            } catch {
                self.logger.error("Failed to cleanup disk cache", category: .cache)
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        logger.warning("Memory warning received, clearing memory cache", category: .cache)
        
        queue.async {
            self.memoryCache.removeAllObjects()
        }
    }
}

// MARK: - Disk Cache Implementation
class DiskCache {
    private let cacheDirectory: URL
    private let capacity: Int
    private let maxAge: TimeInterval
    private let compressionEnabled: Bool
    private let encryptionEnabled: Bool
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.roomfinder.diskcache", qos: .utility)
    
    init(capacity: Int, maxAge: TimeInterval, compressionEnabled: Bool, encryptionEnabled: Bool) {
        self.capacity = capacity
        self.maxAge = maxAge
        self.compressionEnabled = compressionEnabled
        self.encryptionEnabled = encryptionEnabled
        
        // Create cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesDirectory.appendingPathComponent("RoomFinderCache")
        
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to create cache directory: \(error)")
        }
    }
    
    func store(entry: CacheEntry) throws {
        let filename = sanitizeFilename(entry.key)
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        var data = entry.data
        
        if compressionEnabled {
            data = try data.compressed()
        }
        
        if encryptionEnabled {
            data = try data.encrypted()
        }
        
        try data.write(to: fileURL)
        
        // Store metadata
        let metadataURL = cacheDirectory.appendingPathComponent("\(filename).meta")
        let metadata = try JSONEncoder().encode(entry)
        try metadata.write(to: metadataURL)
    }
    
    func retrieve(key: String) throws -> CacheEntry? {
        let filename = sanitizeFilename(key)
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        let metadataURL = cacheDirectory.appendingPathComponent("\(filename).meta")
        
        guard fileManager.fileExists(atPath: fileURL.path),
              fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        
        let metadataData = try Data(contentsOf: metadataURL)
        var entry = try JSONDecoder().decode(CacheEntry.self, from: metadataData)
        
        var data = try Data(contentsOf: fileURL)
        
        if encryptionEnabled {
            data = try data.decrypted()
        }
        
        if compressionEnabled {
            data = try data.decompressed()
        }
        
        // Create new entry with retrieved data
        entry = CacheEntry(key: key, data: data, maxAge: maxAge, metadata: entry.metadata)
        
        return entry
    }
    
    func remove(key: String) throws {
        let filename = sanitizeFilename(key)
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        let metadataURL = cacheDirectory.appendingPathComponent("\(filename).meta")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        if fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.removeItem(at: metadataURL)
        }
    }
    
    func clear() throws {
        let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        
        for file in files {
            try fileManager.removeItem(at: file)
        }
    }
    
    func cleanup() throws -> Int {
        let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
        
        var removedCount = 0
        
        for file in files {
            if file.pathExtension == "meta" {
                do {
                    let metadataData = try Data(contentsOf: file)
                    let entry = try JSONDecoder().decode(CacheEntry.self, from: metadataData)
                    
                    if entry.isExpired {
                        let baseFilename = file.deletingPathExtension().lastPathComponent
                        let dataFile = cacheDirectory.appendingPathComponent(baseFilename)
                        
                        try fileManager.removeItem(at: file)
                        if fileManager.fileExists(atPath: dataFile.path) {
                            try fileManager.removeItem(at: dataFile)
                        }
                        
                        removedCount += 1
                    }
                } catch {
                    // If we can't decode metadata, remove the file
                    try fileManager.removeItem(at: file)
                    removedCount += 1
                }
            }
        }
        
        return removedCount
    }
    
    func getCurrentSize() -> Int {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            var totalSize = 0
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += attributes.fileSize ?? 0
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
    
    private func sanitizeFilename(_ key: String) -> String {
        return key.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? key
    }
}

// MARK: - Specialized Caches

class ListingCache: MultiLevelCache {
    static let shared = ListingCache()
    
    private init() {
        super.init(configuration: .default, strategy: .adaptive)
    }
    
    func cacheListings(_ listings: [Listing], key: String) {
        set(key: key, value: listings, metadata: ["type": "listings", "count": "\(listings.count)"])
    }
    
    func getCachedListings(key: String) async -> [Listing]? {
        return await get(key: key, type: [Listing].self)
    }
}

class ImageCache: MultiLevelCache {
    static let shared = ImageCache()
    
    private init() {
        super.init(configuration: .aggressive, strategy: .lru)
    }
    
    func cacheImage(_ image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        set(key: key, value: data, metadata: ["type": "image"])
    }
    
    func getCachedImage(key: String) async -> UIImage? {
        guard let data = await get(key: key, type: Data.self) else { return nil }
        return UIImage(data: data)
    }
}

class UserCache: MultiLevelCache {
    static let shared = UserCache()
    
    private init() {
        super.init(configuration: .minimal, strategy: .ttl)
    }
    
    func cacheUser(_ user: User, key: String) {
        set(key: key, value: user, maxAge: 30 * 60, metadata: ["type": "user"]) // 30 minutes
    }
    
    func getCachedUser(key: String) async -> User? {
        return await get(key: key, type: User.self)
    }
}

// MARK: - Data Extensions for Compression/Encryption

extension Data {
    func compressed() throws -> Data {
        return try (self as NSData).compressed(using: .lzfse) as Data
    }
    
    func decompressed() throws -> Data {
        return try (self as NSData).decompressed(using: .lzfse) as Data
    }
    
    func encrypted() throws -> Data {
        // Simple XOR encryption (for demonstration - use proper encryption in production)
        let key: UInt8 = 0x42
        return Data(self.map { $0 ^ key })
    }
    
    func decrypted() throws -> Data {
        // Simple XOR decryption (for demonstration - use proper encryption in production)
        let key: UInt8 = 0x42
        return Data(self.map { $0 ^ key })
    }
}

// MARK: - Cache Manager

class CacheManager {
    static let shared = CacheManager()
    
    private let listingCache = ListingCache.shared
    private let imageCache = ImageCache.shared
    private let userCache = UserCache.shared
    
    private init() {}
    
    func clearAllCaches() {
        listingCache.clear()
        imageCache.clear()
        userCache.clear()
    }
    
    func getCacheStatistics() -> [String: Any] {
        let listingStats = listingCache.getStatistics()
        let imageStats = imageCache.getStatistics()
        let userStats = userCache.getStatistics()
        
        return [
            "listings": [
                "hitRate": listingStats.hitRate,
                "hits": listingStats.hits,
                "misses": listingStats.misses
            ],
            "images": [
                "hitRate": imageStats.hitRate,
                "hits": imageStats.hits,
                "misses": imageStats.misses
            ],
            "users": [
                "hitRate": userStats.hitRate,
                "hits": userStats.hits,
                "misses": userStats.misses
            ]
        ]
    }
    
    func getCacheSizes() -> [String: Int] {
        let listingSize = listingCache.getCacheSize()
        let imageSize = imageCache.getCacheSize()
        let userSize = userCache.getCacheSize()
        
        return [
            "listings_memory": listingSize.memorySize,
            "listings_disk": listingSize.diskSize,
            "images_memory": imageSize.memorySize,
            "images_disk": imageSize.diskSize,
            "users_memory": userSize.memorySize,
            "users_disk": userSize.diskSize
        ]
    }
}