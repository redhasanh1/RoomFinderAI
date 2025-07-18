import Foundation
import UIKit
import SwiftUI
import Combine

// MARK: - Image Loading Service
class ImageLoadingService: ObservableObject {
    static let shared = ImageLoadingService()
    
    // MARK: - Properties
    private let cache = NSCache<NSString, UIImage>()
    private let session = InterceptedURLSession.shared
    private var activeDownloads: [String: Task<UIImage, Error>] = [:]
    private let queue = DispatchQueue(label: "ImageLoadingService", qos: .userInitiated)
    
    // Configuration
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 3600 // 1 hour
    
    // Statistics
    @Published var cacheHits: Int = 0
    @Published var cacheMisses: Int = 0
    @Published var totalDownloads: Int = 0
    @Published var failedDownloads: Int = 0
    
    // MARK: - Initialization
    private init() {
        setupCache()
        setupMemoryWarningObserver()
    }
    
    // MARK: - Setup
    private func setupCache() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = 200 // Maximum 200 images
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    // MARK: - Public Methods
    
    func loadImage(from url: URL, size: CGSize? = nil, priority: TaskPriority = .medium) async throws -> UIImage {
        let cacheKey = cacheKey(for: url, size: size)
        
        // Check cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            DispatchQueue.main.async {
                self.cacheHits += 1
            }
            return cachedImage
        }
        
        // Check if already downloading
        if let existingTask = activeDownloads[cacheKey.description] {
            return try await existingTask.value
        }
        
        // Start new download
        let downloadTask = Task(priority: priority) {
            return try await self.downloadImage(from: url, size: size, cacheKey: cacheKey)
        }
        
        activeDownloads[cacheKey.description] = downloadTask
        
        do {
            let image = try await downloadTask.value
            activeDownloads.removeValue(forKey: cacheKey.description)
            return image
        } catch {
            activeDownloads.removeValue(forKey: cacheKey.description)
            throw error
        }
    }
    
    func preloadImages(from urls: [URL], size: CGSize? = nil, priority: TaskPriority = .low) {
        Task(priority: priority) {
            await withTaskGroup(of: Void.self) { group in
                for url in urls {
                    group.addTask {
                        do {
                            _ = try await self.loadImage(from: url, size: size, priority: priority)
                        } catch {
                            // Silently ignore preload errors
                        }
                    }
                }
            }
        }
    }
    
    func clearCache() {
        cache.removeAllObjects()
        LoggingService.shared.info("Image cache cleared", category: .performance)
    }
    
    func cancelDownload(for url: URL, size: CGSize? = nil) {
        let cacheKey = cacheKey(for: url, size: size)
        activeDownloads[cacheKey.description]?.cancel()
        activeDownloads.removeValue(forKey: cacheKey.description)
    }
    
    func getCacheStatistics() -> ImageCacheStatistics {
        return ImageCacheStatistics(
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            totalDownloads: totalDownloads,
            failedDownloads: failedDownloads,
            cacheSize: cache.totalCostLimit,
            cachedItemCount: cache.countLimit
        )
    }
    
    // MARK: - Private Methods
    
    private func downloadImage(from url: URL, size: CGSize?, cacheKey: NSString) async throws -> UIImage {
        DispatchQueue.main.async {
            self.cacheMisses += 1
            self.totalDownloads += 1
        }
        
        do {
            let (data, _) = try await session.data(from: url)
            
            guard let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    self.failedDownloads += 1
                }
                throw ImageLoadingError.invalidImageData
            }
            
            // Resize if needed
            let processedImage = if let size = size {
                image.resized(to: size)
            } else {
                image
            }
            
            // Cache the image
            let cost = data.count
            cache.setObject(processedImage, forKey: cacheKey, cost: cost)
            
            LoggingService.shared.info(
                "Image downloaded and cached",
                category: .performance,
                metadata: [
                    "url": url.absoluteString,
                    "size": "\(Int(processedImage.size.width))x\(Int(processedImage.size.height))",
                    "cost": cost
                ]
            )
            
            return processedImage
        } catch {
            DispatchQueue.main.async {
                self.failedDownloads += 1
            }
            throw error
        }
    }
    
    private func cacheKey(for url: URL, size: CGSize?) -> NSString {
        var key = url.absoluteString
        if let size = size {
            key += "_\(Int(size.width))x\(Int(size.height))"
        }
        return key as NSString
    }
}

// MARK: - Image Loading Error
enum ImageLoadingError: Error, LocalizedError {
    case invalidURL
    case invalidImageData
    case downloadFailed(Error)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .invalidImageData:
            return "Invalid image data"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .cancelled:
            return "Download cancelled"
        }
    }
}

// MARK: - Image Cache Statistics
struct ImageCacheStatistics {
    let cacheHits: Int
    let cacheMisses: Int
    let totalDownloads: Int
    let failedDownloads: Int
    let cacheSize: Int
    let cachedItemCount: Int
    
    var hitRate: Double {
        let total = cacheHits + cacheMisses
        guard total > 0 else { return 0 }
        return Double(cacheHits) / Double(total)
    }
    
    var successRate: Double {
        guard totalDownloads > 0 else { return 0 }
        return Double(totalDownloads - failedDownloads) / Double(totalDownloads)
    }
}

// MARK: - UIImage Extensions
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func resized(to targetSize: CGSize, contentMode: UIView.ContentMode = .scaleAspectFit) -> UIImage {
        let size = self.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        var newSize: CGSize
        
        switch contentMode {
        case .scaleAspectFit:
            let ratio = min(widthRatio, heightRatio)
            newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        case .scaleAspectFill:
            let ratio = max(widthRatio, heightRatio)
            newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        default:
            newSize = targetSize
        }
        
        return resized(to: newSize)
    }
    
    func compressed(quality: CGFloat = 0.8) -> Data? {
        return jpegData(compressionQuality: quality)
    }
}

// MARK: - AsyncImage with Caching
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let size: CGSize?
    let priority: TaskPriority
    let content: (UIImage) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var imageLoader = ImageLoadingService.shared
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    
    init(
        url: URL?,
        size: CGSize? = nil,
        priority: TaskPriority = .medium,
        @ViewBuilder content: @escaping (UIImage) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.size = size
        self.priority = priority
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(image)
            } else if isLoading {
                placeholder()
            } else if error != nil {
                placeholder()
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            cancelLoad()
        }
        .onChange(of: url) { _, newURL in
            image = nil
            error = nil
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let loadedImage = try await imageLoader.loadImage(from: url, size: size, priority: priority)
                
                await MainActor.run {
                    self.image = loadedImage
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
    
    private func cancelLoad() {
        guard let url = url else { return }
        imageLoader.cancelDownload(for: url, size: size)
    }
}

// MARK: - Convenience Initializers
extension CachedAsyncImage where Content == Image, Placeholder == Rectangle {
    init(url: URL?, size: CGSize? = nil, priority: TaskPriority = .medium) {
        self.init(
            url: url,
            size: size,
            priority: priority,
            content: { uiImage in
                Image(uiImage: uiImage)
                    .resizable()
            },
            placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        )
    }
}

extension CachedAsyncImage where Placeholder == Rectangle {
    init(
        url: URL?,
        size: CGSize? = nil,
        priority: TaskPriority = .medium,
        @ViewBuilder content: @escaping (UIImage) -> Content
    ) {
        self.init(
            url: url,
            size: size,
            priority: priority,
            content: content,
            placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
        )
    }
}

// MARK: - LazyImage View
struct LazyImage: View {
    let url: URL?
    let size: CGSize?
    let contentMode: ContentMode
    let placeholder: AnyView?
    let errorView: AnyView?
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    
    init(
        url: URL?,
        size: CGSize? = nil,
        contentMode: ContentMode = .fit,
        placeholder: AnyView? = nil,
        errorView: AnyView? = nil
    ) {
        self.url = url
        self.size = size
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.errorView = errorView
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                placeholder ?? AnyView(
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            } else if error != nil {
                errorView ?? AnyView(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            } else {
                placeholder ?? AnyView(
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                )
            }
        }
        .onAppear {
            loadImage()
        }
        .onDisappear {
            cancelLoad()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let loadedImage = try await ImageLoadingService.shared.loadImage(from: url, size: size)
                
                await MainActor.run {
                    self.image = loadedImage
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
    
    private func cancelLoad() {
        guard let url = url else { return }
        ImageLoadingService.shared.cancelDownload(for: url, size: size)
    }
}

// MARK: - Image Grid View
struct LazyImageGrid: View {
    let urls: [URL]
    let columns: Int
    let spacing: CGFloat
    let itemSize: CGSize
    
    init(urls: [URL], columns: Int = 2, spacing: CGFloat = 8, itemSize: CGSize = CGSize(width: 150, height: 150)) {
        self.urls = urls
        self.columns = columns
        self.spacing = spacing
        self.itemSize = itemSize
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(urls, id: \.self) { url in
                CachedAsyncImage(url: url, size: itemSize)
                    .frame(width: itemSize.width, height: itemSize.height)
                    .clipped()
                    .cornerRadius(8)
            }
        }
        .onAppear {
            preloadImages()
        }
    }
    
    private func preloadImages() {
        ImageLoadingService.shared.preloadImages(from: urls, size: itemSize)
    }
}