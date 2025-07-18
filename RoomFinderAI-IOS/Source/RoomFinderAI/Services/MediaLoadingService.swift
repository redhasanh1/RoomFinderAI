import Foundation
import AVFoundation
import UIKit
import SwiftUI
import Combine

// MARK: - Media Loading Service
class MediaLoadingService: ObservableObject {
    static let shared = MediaLoadingService()
    
    // MARK: - Properties
    private let urlSession = InterceptedURLSession.shared
    private let fileManager = FileManager.default
    private var activeDownloads: [String: Task<URL, Error>] = [:]
    private var thumbnailCache = NSCache<NSString, UIImage>()
    
    // Cache directory
    private lazy var cacheDirectory: URL = {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("MediaCache")
        try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        return cacheURL
    }()
    
    // Configuration
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private let maxThumbnailCacheSize = 50 * 1024 * 1024 // 50MB
    
    // Statistics
    @Published var cacheHits: Int = 0
    @Published var cacheMisses: Int = 0
    @Published var totalDownloads: Int = 0
    @Published var failedDownloads: Int = 0
    @Published var cacheSize: Int64 = 0
    
    // MARK: - Initialization
    private init() {
        setupThumbnailCache()
        setupMemoryWarningObserver()
        calculateCacheSize()
    }
    
    // MARK: - Setup
    private func setupThumbnailCache() {
        thumbnailCache.totalCostLimit = maxThumbnailCacheSize
        thumbnailCache.countLimit = 100
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearThumbnailCache()
        }
    }
    
    private func calculateCacheSize() {
        Task {
            let size = await getCacheDirectorySize()
            await MainActor.run {
                self.cacheSize = size
            }
        }
    }
    
    // MARK: - Public Methods
    
    // MARK: - Video Loading
    func loadVideo(from url: URL, priority: TaskPriority = .medium) async throws -> URL {
        let cacheKey = cacheKey(for: url)
        let localURL = cacheDirectory.appendingPathComponent(cacheKey)
        
        // Check if already cached
        if fileManager.fileExists(atPath: localURL.path) {
            DispatchQueue.main.async {
                self.cacheHits += 1
            }
            return localURL
        }
        
        // Check if already downloading
        if let existingTask = activeDownloads[cacheKey] {
            return try await existingTask.value
        }
        
        // Start new download
        let downloadTask = Task(priority: priority) {
            return try await self.downloadVideo(from: url, to: localURL, cacheKey: cacheKey)
        }
        
        activeDownloads[cacheKey] = downloadTask
        
        do {
            let videoURL = try await downloadTask.value
            activeDownloads.removeValue(forKey: cacheKey)
            return videoURL
        } catch {
            activeDownloads.removeValue(forKey: cacheKey)
            throw error
        }
    }
    
    // MARK: - Audio Loading
    func loadAudio(from url: URL, priority: TaskPriority = .medium) async throws -> URL {
        let cacheKey = cacheKey(for: url, suffix: "audio")
        let localURL = cacheDirectory.appendingPathComponent(cacheKey)
        
        // Check if already cached
        if fileManager.fileExists(atPath: localURL.path) {
            DispatchQueue.main.async {
                self.cacheHits += 1
            }
            return localURL
        }
        
        // Check if already downloading
        if let existingTask = activeDownloads[cacheKey] {
            return try await existingTask.value
        }
        
        // Start new download
        let downloadTask = Task(priority: priority) {
            return try await self.downloadMedia(from: url, to: localURL, cacheKey: cacheKey)
        }
        
        activeDownloads[cacheKey] = downloadTask
        
        do {
            let audioURL = try await downloadTask.value
            activeDownloads.removeValue(forKey: cacheKey)
            return audioURL
        } catch {
            activeDownloads.removeValue(forKey: cacheKey)
            throw error
        }
    }
    
    // MARK: - Thumbnail Generation
    func generateThumbnail(for videoURL: URL, time: CMTime = CMTime(seconds: 1, preferredTimescale: 600)) async throws -> UIImage {
        let cacheKey = thumbnailCacheKey(for: videoURL, time: time)
        
        // Check cache first
        if let cachedThumbnail = thumbnailCache.object(forKey: cacheKey) {
            return cachedThumbnail
        }
        
        // Generate thumbnail
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        do {
            let cgImage = try await imageGenerator.image(at: time).image
            let thumbnail = UIImage(cgImage: cgImage)
            
            // Cache the thumbnail
            let cost = Int(thumbnail.size.width * thumbnail.size.height * 4) // Approximate memory cost
            thumbnailCache.setObject(thumbnail, forKey: cacheKey, cost: cost)
            
            return thumbnail
        } catch {
            throw MediaLoadingError.thumbnailGenerationFailed(error)
        }
    }
    
    // MARK: - Preloading
    func preloadVideos(from urls: [URL], priority: TaskPriority = .low) {
        Task(priority: priority) {
            await withTaskGroup(of: Void.self) { group in
                for url in urls {
                    group.addTask {
                        do {
                            _ = try await self.loadVideo(from: url, priority: priority)
                        } catch {
                            // Silently ignore preload errors
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Cache Management
    func clearCache() {
        do {
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for fileURL in cacheContents {
                try fileManager.removeItem(at: fileURL)
            }
            
            thumbnailCache.removeAllObjects()
            
            DispatchQueue.main.async {
                self.cacheSize = 0
            }
            
            LoggingService.shared.info("Media cache cleared", category: .performance)
        } catch {
            LoggingService.shared.error("Failed to clear media cache: \(error.localizedDescription)", category: .performance)
        }
    }
    
    func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
        LoggingService.shared.info("Thumbnail cache cleared", category: .performance)
    }
    
    func cleanupOldFiles() {
        Task {
            await performCacheCleanup()
        }
    }
    
    func cancelDownload(for url: URL) {
        let cacheKey = cacheKey(for: url)
        activeDownloads[cacheKey]?.cancel()
        activeDownloads.removeValue(forKey: cacheKey)
    }
    
    func getCacheStatistics() -> MediaCacheStatistics {
        return MediaCacheStatistics(
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            totalDownloads: totalDownloads,
            failedDownloads: failedDownloads,
            cacheSize: cacheSize,
            maxCacheSize: maxCacheSize,
            thumbnailCacheSize: thumbnailCache.totalCostLimit
        )
    }
    
    // MARK: - Private Methods
    
    private func downloadVideo(from url: URL, to localURL: URL, cacheKey: String) async throws -> URL {
        return try await downloadMedia(from: url, to: localURL, cacheKey: cacheKey)
    }
    
    private func downloadMedia(from url: URL, to localURL: URL, cacheKey: String) async throws -> URL {
        DispatchQueue.main.async {
            self.cacheMisses += 1
            self.totalDownloads += 1
        }
        
        do {
            let (downloadURL, _) = try await urlSession.download(from: url)
            
            // Move downloaded file to cache directory
            try fileManager.moveItem(at: downloadURL, to: localURL)
            
            // Update cache size
            let fileSize = try fileManager.attributesOfItem(atPath: localURL.path)[.size] as? Int64 ?? 0
            await MainActor.run {
                self.cacheSize += fileSize
            }
            
            LoggingService.shared.info(
                "Media file downloaded and cached",
                category: .performance,
                metadata: [
                    "url": url.absoluteString,
                    "size": fileSize,
                    "cacheKey": cacheKey
                ]
            )
            
            // Cleanup if cache is getting too large
            if cacheSize > maxCacheSize {
                await performCacheCleanup()
            }
            
            return localURL
        } catch {
            DispatchQueue.main.async {
                self.failedDownloads += 1
            }
            throw error
        }
    }
    
    private func performCacheCleanup() async {
        do {
            let cacheContents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
            )
            
            // Sort by modification date (oldest first)
            let sortedFiles = cacheContents.sorted { url1, url2 in
                let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date.distantPast
                return date1 < date2
            }
            
            var currentSize = cacheSize
            let targetSize = Int64(Double(maxCacheSize) * 0.8) // Remove files until we're at 80% capacity
            
            for fileURL in sortedFiles {
                guard currentSize > targetSize else { break }
                
                do {
                    let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    try fileManager.removeItem(at: fileURL)
                    currentSize -= Int64(fileSize)
                    
                    LoggingService.shared.info(
                        "Removed cached media file",
                        category: .performance,
                        metadata: ["file": fileURL.lastPathComponent, "size": fileSize]
                    )
                } catch {
                    LoggingService.shared.error(
                        "Failed to remove cached file: \(error.localizedDescription)",
                        category: .performance
                    )
                }
            }
            
            await MainActor.run {
                self.cacheSize = currentSize
            }
        } catch {
            LoggingService.shared.error("Cache cleanup failed: \(error.localizedDescription)", category: .performance)
        }
    }
    
    private func getCacheDirectorySize() async -> Int64 {
        do {
            let cacheContents = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            var totalSize: Int64 = 0
            for fileURL in cacheContents {
                let fileSize = try fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                totalSize += Int64(fileSize)
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
    
    private func cacheKey(for url: URL, suffix: String = "video") -> String {
        let fileName = url.lastPathComponent
        let hash = url.absoluteString.hash
        return "\(suffix)_\(hash)_\(fileName)"
    }
    
    private func thumbnailCacheKey(for url: URL, time: CMTime) -> NSString {
        let timeString = String(format: "%.2f", time.seconds)
        return "\(url.absoluteString)_\(timeString)" as NSString
    }
}

// MARK: - Media Loading Error
enum MediaLoadingError: Error, LocalizedError {
    case invalidURL
    case downloadFailed(Error)
    case thumbnailGenerationFailed(Error)
    case fileNotFound
    case cacheError(Error)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid media URL"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .thumbnailGenerationFailed(let error):
            return "Thumbnail generation failed: \(error.localizedDescription)"
        case .fileNotFound:
            return "Media file not found"
        case .cacheError(let error):
            return "Cache error: \(error.localizedDescription)"
        case .cancelled:
            return "Download cancelled"
        }
    }
}

// MARK: - Media Cache Statistics
struct MediaCacheStatistics {
    let cacheHits: Int
    let cacheMisses: Int
    let totalDownloads: Int
    let failedDownloads: Int
    let cacheSize: Int64
    let maxCacheSize: Int64
    let thumbnailCacheSize: Int
    
    var hitRate: Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0 }
        return Double(cacheHits) / Double(total)
    }
    
    var successRate: Double {
        guard totalDownloads > 0 else { return 0 }
        return Double(totalDownloads - failedDownloads) / Double(totalDownloads)
    }
    
    var cacheUtilization: Double {
        guard maxCacheSize > 0 else { return 0 }
        return Double(cacheSize) / Double(maxCacheSize)
    }
    
    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }
    
    var formattedMaxCacheSize: String {
        ByteCountFormatter.string(fromByteCount: maxCacheSize, countStyle: .file)
    }
}

// MARK: - Lazy Video Player
struct LazyVideoPlayer: View {
    let url: URL?
    let showControls: Bool
    let autoplay: Bool
    let loop: Bool
    
    @State private var player: AVPlayer?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var thumbnail: UIImage?
    
    init(
        url: URL?,
        showControls: Bool = true,
        autoplay: Bool = false,
        loop: Bool = false
    ) {
        self.url = url
        self.showControls = showControls
        self.autoplay = autoplay
        self.loop = loop
    }
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        if autoplay {
                            player.play()
                        }
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else if isLoading {
                ZStack {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(Color.black.opacity(0.8))
                    }
                    
                    ProgressView()
                        .tint(.white)
                }
            } else if error != nil {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Failed to load video")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "video")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func loadVideo() {
        guard let url = url else { return }
        
        isLoading = true
        error = nil
        
        // First, try to generate a thumbnail
        Task {
            do {
                let thumbnailImage = try await MediaLoadingService.shared.generateThumbnail(for: url)
                await MainActor.run {
                    self.thumbnail = thumbnailImage
                }
            } catch {
                // Ignore thumbnail errors
            }
        }
        
        // Then load the video
        Task {
            do {
                let localURL = try await MediaLoadingService.shared.loadVideo(from: url)
                
                await MainActor.run {
                    let avPlayer = AVPlayer(url: localURL)
                    
                    if self.loop {
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: avPlayer.currentItem,
                            queue: .main
                        ) { _ in
                            avPlayer.seek(to: .zero)
                            avPlayer.play()
                        }
                    }
                    
                    self.player = avPlayer
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private func cleanup() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let url: URL?
    let time: CMTime
    let size: CGSize?
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    
    init(url: URL?, time: CMTime = CMTime(seconds: 1, preferredTimescale: 600), size: CGSize? = nil) {
        self.url = url
        self.time = time
        self.size = size
    }
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if error != nil {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "video")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard let url = url else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let thumbnailImage = try await MediaLoadingService.shared.generateThumbnail(for: url, time: time)
                
                await MainActor.run {
                    self.thumbnail = thumbnailImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Media Grid View
struct MediaGridView: View {
    let mediaItems: [MediaItem]
    let columns: Int
    let spacing: CGFloat
    let itemSize: CGSize
    
    init(
        mediaItems: [MediaItem],
        columns: Int = 2,
        spacing: CGFloat = 8,
        itemSize: CGSize = CGSize(width: 150, height: 150)
    ) {
        self.mediaItems = mediaItems
        self.columns = columns
        self.spacing = spacing
        self.itemSize = itemSize
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(mediaItems, id: \.id) { item in
                MediaItemView(item: item, size: itemSize)
            }
        }
        .onAppear {
            preloadMedia()
        }
    }
    
    private func preloadMedia() {
        let videoURLs = mediaItems.compactMap { item in
            item.type == .video ? item.url : nil
        }
        
        MediaLoadingService.shared.preloadVideos(from: videoURLs)
    }
}

// MARK: - Media Item
struct MediaItem: Identifiable {
    let id = UUID()
    let url: URL
    let type: MediaType
    let title: String?
    let thumbnail: URL?
    
    enum MediaType {
        case image
        case video
        case audio
    }
}

// MARK: - Media Item View
struct MediaItemView: View {
    let item: MediaItem
    let size: CGSize
    
    var body: some View {
        Group {
            switch item.type {
            case .image:
                CachedAsyncImage(url: item.url, size: size)
            case .video:
                VideoThumbnailView(url: item.url, size: size)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    )
            case .audio:
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "music.note")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            if let title = item.title {
                                Text(title)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .lineLimit(2)
                            }
                        }
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .cornerRadius(8)
    }
}