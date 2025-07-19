import XCTest
import UIKit
import Combine
@testable import RoomFinderAI

class ImageLoadingServiceTests: XCTestCase {
    var imageService: ImageLoadingService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        imageService = ImageLoadingService.shared
        cancellables = Set<AnyCancellable>()
        imageService.clearCache()
    }
    
    override func tearDown() {
        imageService.clearCache()
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Image Loading Tests
    
    func testLoadImageFromURL() async throws {
        // Given
        let url = URL(string: "https://httpbin.org/image/png")!
        
        // When
        let image = try await imageService.loadImage(from: url)
        
        // Then
        XCTAssertNotNil(image)
        XCTAssertTrue(image.size.width > 0)
        XCTAssertTrue(image.size.height > 0)
    }
    
    func testLoadImageWithSize() async throws {
        // Given
        let url = URL(string: "https://httpbin.org/image/png")!
        let targetSize = CGSize(width: 100, height: 100)
        
        // When
        let image = try await imageService.loadImage(from: url, size: targetSize)
        
        // Then
        XCTAssertNotNil(image)
        XCTAssertEqual(image.size, targetSize)
    }
    
    func testImageCaching() async throws {
        // Given
        let url = URL(string: "https://httpbin.org/image/png")!
        let initialStats = imageService.getCacheStatistics()
        
        // When - First load
        let image1 = try await imageService.loadImage(from: url)
        let statsAfterFirstLoad = imageService.getCacheStatistics()
        
        // Then - Should be a cache miss
        XCTAssertNotNil(image1)
        XCTAssertEqual(statsAfterFirstLoad.cacheMisses, initialStats.cacheMisses + 1)
        
        // When - Second load
        let image2 = try await imageService.loadImage(from: url)
        let statsAfterSecondLoad = imageService.getCacheStatistics()
        
        // Then - Should be a cache hit
        XCTAssertNotNil(image2)
        XCTAssertEqual(statsAfterSecondLoad.cacheHits, statsAfterFirstLoad.cacheHits + 1)
    }
    
    func testPreloadImages() async throws {
        // Given
        let urls = [
            URL(string: "https://httpbin.org/image/png")!,
            URL(string: "https://httpbin.org/image/jpeg")!
        ]
        
        // When
        imageService.preloadImages(from: urls)
        
        // Give some time for preloading
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Then
        let stats = imageService.getCacheStatistics()
        XCTAssertGreaterThan(stats.totalDownloads, 0)
    }
    
    func testCancelDownload() async throws {
        // Given
        let url = URL(string: "https://httpbin.org/delay/5")! // Slow endpoint
        
        // When
        let loadTask = Task {
            try await imageService.loadImage(from: url)
        }
        
        // Cancel immediately
        imageService.cancelDownload(for: url)
        loadTask.cancel()
        
        // Then
        do {
            _ = try await loadTask.value
            XCTFail("Should have been cancelled")
        } catch {
            // Expected to be cancelled
        }
    }
    
    func testClearCache() async throws {
        // Given
        let url = URL(string: "https://httpbin.org/image/png")!
        _ = try await imageService.loadImage(from: url)
        
        let statsBeforeClear = imageService.getCacheStatistics()
        XCTAssertGreaterThan(statsBeforeClear.cacheHits + statsBeforeClear.cacheMisses, 0)
        
        // When
        imageService.clearCache()
        
        // Then
        // Load the same image again should be a cache miss
        _ = try await imageService.loadImage(from: url)
        let statsAfterClear = imageService.getCacheStatistics()
        XCTAssertEqual(statsAfterClear.cacheHits, 0)
    }
    
    // MARK: - Cache Statistics Tests
    
    func testCacheStatistics() async throws {
        // Given
        let url = URL(string: "https://httpbin.org/image/png")!
        let initialStats = imageService.getCacheStatistics()
        
        // When
        _ = try await imageService.loadImage(from: url)
        let statsAfterLoad = imageService.getCacheStatistics()
        
        // Then
        XCTAssertEqual(statsAfterLoad.totalDownloads, initialStats.totalDownloads + 1)
        XCTAssertEqual(statsAfterLoad.cacheMisses, initialStats.cacheMisses + 1)
        XCTAssertTrue(statsAfterLoad.hitRate >= 0)
        XCTAssertTrue(statsAfterLoad.successRate >= 0)
    }
    
    func testCacheStatisticsHitRate() async throws {
        // Given
        let url = URL(string: "https://httpbin.org/image/png")!
        
        // When
        _ = try await imageService.loadImage(from: url) // Cache miss
        _ = try await imageService.loadImage(from: url) // Cache hit
        
        let stats = imageService.getCacheStatistics()
        
        // Then
        XCTAssertEqual(stats.hitRate, 0.5, accuracy: 0.01) // 1 hit out of 2 total
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadImageWithInvalidURL() async {
        // Given
        let invalidURL = URL(string: "https://invalid-url-that-does-not-exist.com/image.png")!
        
        // When & Then
        do {
            _ = try await imageService.loadImage(from: invalidURL)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is URLError || error is ImageLoadingError)
        }
    }
    
    func testLoadImageWithNonImageURL() async {
        // Given
        let nonImageURL = URL(string: "https://httpbin.org/json")!
        
        // When & Then
        do {
            _ = try await imageService.loadImage(from: nonImageURL)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is ImageLoadingError)
        }
    }
    
    // MARK: - Concurrent Loading Tests
    
    func testConcurrentImageLoading() async throws {
        // Given
        let urls = Array(1...5).map { URL(string: "https://httpbin.org/image/png?id=\($0)")! }
        
        // When
        let results = await withTaskGroup(of: Result<UIImage, Error>.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        let image = try await self.imageService.loadImage(from: url)
                        return .success(image)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            var results: [Result<UIImage, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // Then
        XCTAssertEqual(results.count, urls.count)
        let successCount = results.filter { if case .success = $0 { return true } else { return false } }.count
        XCTAssertGreaterThan(successCount, 0)
    }
    
    // MARK: - UIImage Extension Tests
    
    func testUIImageResize() {
        // Given
        let originalImage = UIImage(systemName: "star.fill")!
        let targetSize = CGSize(width: 100, height: 100)
        
        // When
        let resizedImage = originalImage.resized(to: targetSize)
        
        // Then
        XCTAssertEqual(resizedImage.size, targetSize)
    }
    
    func testUIImageResizeWithContentMode() {
        // Given
        let originalImage = UIImage(systemName: "star.fill")!
        let targetSize = CGSize(width: 100, height: 50)
        
        // When
        let aspectFitImage = originalImage.resized(to: targetSize, contentMode: .scaleAspectFit)
        let aspectFillImage = originalImage.resized(to: targetSize, contentMode: .scaleAspectFill)
        
        // Then
        XCTAssertNotNil(aspectFitImage)
        XCTAssertNotNil(aspectFillImage)
        // The exact size will depend on the aspect ratio of the original image
    }
    
    func testUIImageCompression() {
        // Given
        let originalImage = UIImage(systemName: "star.fill")!
        
        // When
        let compressedData = originalImage.compressed(quality: 0.8)
        
        // Then
        XCTAssertNotNil(compressedData)
        XCTAssertGreaterThan(compressedData!.count, 0)
    }
    
    // MARK: - Image Loading Error Tests
    
    func testImageLoadingErrorDescriptions() {
        // Given
        let errors: [ImageLoadingError] = [
            .invalidURL,
            .invalidImageData,
            .downloadFailed(URLError(.badURL)),
            .cancelled
        ]
        
        // When & Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryWarningHandling() async throws {
        // Given
        let url = URL(string: "https://httpbin.org/image/png")!
        _ = try await imageService.loadImage(from: url)
        
        // When
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Give some time for the memory warning to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then
        // The cache should be cleared, so loading the same image should be a cache miss
        let statsBeforeReload = imageService.getCacheStatistics()
        _ = try await imageService.loadImage(from: url)
        let statsAfterReload = imageService.getCacheStatistics()
        
        XCTAssertEqual(statsAfterReload.cacheMisses, statsBeforeReload.cacheMisses + 1)
    }
    
    // MARK: - Performance Tests
    
    func testImageLoadingPerformance() async throws {
        // Given
        let urls = Array(1...10).map { URL(string: "https://httpbin.org/image/png?id=\($0)")! }
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    do {
                        _ = try await self.imageService.loadImage(from: url)
                    } catch {
                        // Ignore errors for performance test
                    }
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Then
        XCTAssertLessThan(duration, 30.0) // Should complete within 30 seconds
        
        let stats = imageService.getCacheStatistics()
        XCTAssertGreaterThan(stats.totalDownloads, 0)
    }
}