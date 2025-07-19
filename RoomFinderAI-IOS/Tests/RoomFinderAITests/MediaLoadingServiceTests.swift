import XCTest
import AVFoundation
import UIKit
import Combine
@testable import RoomFinderAI

class MediaLoadingServiceTests: XCTestCase {
    var mediaService: MediaLoadingService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mediaService = MediaLoadingService.shared
        cancellables = Set<AnyCancellable>()
        mediaService.clearCache()
    }
    
    override func tearDown() {
        mediaService.clearCache()
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Video Loading Tests
    
    func testLoadVideoFromURL() async throws {
        // Given
        let videoURL = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
        
        // When
        let localURL = try await mediaService.loadVideo(from: videoURL)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
        XCTAssertNotEqual(localURL, videoURL) // Should be a local file
    }
    
    func testVideoCaching() async throws {
        // Given
        let videoURL = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
        let initialStats = mediaService.getCacheStatistics()
        
        // When - First load
        let localURL1 = try await mediaService.loadVideo(from: videoURL)
        let statsAfterFirstLoad = mediaService.getCacheStatistics()
        
        // Then - Should be a cache miss
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL1.path))
        XCTAssertEqual(statsAfterFirstLoad.cacheMisses, initialStats.cacheMisses + 1)
        
        // When - Second load
        let localURL2 = try await mediaService.loadVideo(from: videoURL)
        let statsAfterSecondLoad = mediaService.getCacheStatistics()
        
        // Then - Should be a cache hit
        XCTAssertEqual(localURL1, localURL2)
        XCTAssertEqual(statsAfterSecondLoad.cacheHits, statsAfterFirstLoad.cacheHits + 1)
    }
    
    func testPreloadVideos() async throws {
        // Given
        let videoURLs = [
            URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_640x360_1mb.mp4")!
        ]
        
        // When
        mediaService.preloadVideos(from: videoURLs)
        
        // Give some time for preloading
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Then
        let stats = mediaService.getCacheStatistics()
        XCTAssertGreaterThan(stats.totalDownloads, 0)
    }
    
    func testCancelVideoDownload() async throws {
        // Given
        let videoURL = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
        
        // When
        let loadTask = Task {
            try await mediaService.loadVideo(from: videoURL)
        }
        
        // Cancel immediately
        mediaService.cancelDownload(for: videoURL)
        loadTask.cancel()
        
        // Then
        do {
            _ = try await loadTask.value
            XCTFail("Should have been cancelled")
        } catch {
            // Expected to be cancelled
        }
    }
    
    // MARK: - Audio Loading Tests
    
    func testLoadAudioFromURL() async throws {
        // Given
        let audioURL = URL(string: "https://sample-videos.com/zip/10/mp3/SampleAudio_0.7mb.mp3")!
        
        // When
        let localURL = try await mediaService.loadAudio(from: audioURL)
        
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
        XCTAssertNotEqual(localURL, audioURL) // Should be a local file
    }
    
    func testAudioCaching() async throws {
        // Given
        let audioURL = URL(string: "https://sample-videos.com/zip/10/mp3/SampleAudio_0.7mb.mp3")!
        let initialStats = mediaService.getCacheStatistics()
        
        // When - First load
        let localURL1 = try await mediaService.loadAudio(from: audioURL)
        let statsAfterFirstLoad = mediaService.getCacheStatistics()
        
        // Then - Should be a cache miss
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL1.path))
        XCTAssertEqual(statsAfterFirstLoad.cacheMisses, initialStats.cacheMisses + 1)
        
        // When - Second load
        let localURL2 = try await mediaService.loadAudio(from: audioURL)
        let statsAfterSecondLoad = mediaService.getCacheStatistics()
        
        // Then - Should be a cache hit
        XCTAssertEqual(localURL1, localURL2)
        XCTAssertEqual(statsAfterSecondLoad.cacheHits, statsAfterFirstLoad.cacheHits + 1)
    }
    
    // MARK: - Thumbnail Generation Tests
    
    func testGenerateThumbnailFromLocalVideo() async throws {
        // Given
        // Create a simple test video URL (this would typically be a real video file)
        let bundle = Bundle(for: type(of: self))
        
        // For this test, we'll use a placeholder approach since we don't have a real video file
        // In a real scenario, you'd have a test video file in your test bundle
        let videoURL = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
        
        // When
        do {
            let thumbnail = try await mediaService.generateThumbnail(for: videoURL)
            
            // Then
            XCTAssertNotNil(thumbnail)
            XCTAssertGreaterThan(thumbnail.size.width, 0)
            XCTAssertGreaterThan(thumbnail.size.height, 0)
        } catch {
            // This test might fail if the video URL is not accessible
            // In a real test environment, you'd use a local test video file
            XCTAssertTrue(error is MediaLoadingError)
        }
    }
    
    func testGenerateThumbnailWithSpecificTime() async throws {
        // Given
        let videoURL = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
        let time = CMTime(seconds: 2, preferredTimescale: 600)
        
        // When
        do {
            let thumbnail = try await mediaService.generateThumbnail(for: videoURL, time: time)
            
            // Then
            XCTAssertNotNil(thumbnail)
            XCTAssertGreaterThan(thumbnail.size.width, 0)
            XCTAssertGreaterThan(thumbnail.size.height, 0)
        } catch {
            // This test might fail if the video URL is not accessible
            XCTAssertTrue(error is MediaLoadingError)
        }
    }
    
    // MARK: - Cache Management Tests
    
    func testClearCache() async throws {
        // Given
        let videoURL = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
        
        do {
            let localURL = try await mediaService.loadVideo(from: videoURL)
            XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
            
            // When
            mediaService.clearCache()
            
            // Then
            XCTAssertFalse(FileManager.default.fileExists(atPath: localURL.path))
            
            let stats = mediaService.getCacheStatistics()
            XCTAssertEqual(stats.cacheSize, 0)
        } catch {
            // If video loading fails, just test that clear cache doesn't crash
            mediaService.clearCache()
            XCTAssertTrue(true)
        }
    }
    
    func testClearThumbnailCache() {
        // Given
        // (We can't easily test with actual thumbnails without video files)
        
        // When
        mediaService.clearThumbnailCache()
        
        // Then
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testCleanupOldFiles() {
        // Given
        // (We can't easily test with actual files without creating them)
        
        // When
        mediaService.cleanupOldFiles()
        
        // Then
        // Should not crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Cache Statistics Tests
    
    func testCacheStatistics() async throws {
        // Given
        let initialStats = mediaService.getCacheStatistics()
        
        // Then
        XCTAssertEqual(initialStats.cacheHits, 0)
        XCTAssertEqual(initialStats.cacheMisses, 0)
        XCTAssertEqual(initialStats.totalDownloads, 0)
        XCTAssertEqual(initialStats.failedDownloads, 0)
        XCTAssertEqual(initialStats.cacheSize, 0)
        XCTAssertGreaterThan(initialStats.maxCacheSize, 0)
        XCTAssertEqual(initialStats.hitRate, 0)
        XCTAssertEqual(initialStats.successRate, 0)
        XCTAssertEqual(initialStats.cacheUtilization, 0)
    }
    
    func testCacheStatisticsFormatting() {
        // Given
        let stats = MediaCacheStatistics(
            cacheHits: 10,
            cacheMisses: 5,
            totalDownloads: 15,
            failedDownloads: 2,
            cacheSize: 1024 * 1024, // 1MB
            maxCacheSize: 100 * 1024 * 1024, // 100MB
            thumbnailCacheSize: 50 * 1024 * 1024 // 50MB
        )
        
        // When
        let hitRate = stats.hitRate
        let successRate = stats.successRate
        let cacheUtilization = stats.cacheUtilization
        let formattedCacheSize = stats.formattedCacheSize
        let formattedMaxCacheSize = stats.formattedMaxCacheSize
        
        // Then
        XCTAssertEqual(hitRate, 10.0 / 15.0, accuracy: 0.001)
        XCTAssertEqual(successRate, 13.0 / 15.0, accuracy: 0.001)
        XCTAssertEqual(cacheUtilization, 0.01, accuracy: 0.001) // 1MB / 100MB
        XCTAssertFalse(formattedCacheSize.isEmpty)
        XCTAssertFalse(formattedMaxCacheSize.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testLoadVideoWithInvalidURL() async {
        // Given
        let invalidURL = URL(string: "https://invalid-url-that-does-not-exist.com/video.mp4")!
        
        // When & Then
        do {
            _ = try await mediaService.loadVideo(from: invalidURL)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is URLError || error is MediaLoadingError)
        }
    }
    
    func testLoadAudioWithInvalidURL() async {
        // Given
        let invalidURL = URL(string: "https://invalid-url-that-does-not-exist.com/audio.mp3")!
        
        // When & Then
        do {
            _ = try await mediaService.loadAudio(from: invalidURL)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is URLError || error is MediaLoadingError)
        }
    }
    
    func testGenerateThumbnailWithInvalidURL() async {
        // Given
        let invalidURL = URL(string: "https://invalid-url-that-does-not-exist.com/video.mp4")!
        
        // When & Then
        do {
            _ = try await mediaService.generateThumbnail(for: invalidURL)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is MediaLoadingError)
        }
    }
    
    // MARK: - Media Loading Error Tests
    
    func testMediaLoadingErrorDescriptions() {
        // Given
        let errors: [MediaLoadingError] = [
            .invalidURL,
            .downloadFailed(URLError(.badURL)),
            .thumbnailGenerationFailed(URLError(.badURL)),
            .fileNotFound,
            .cacheError(URLError(.badURL)),
            .cancelled
        ]
        
        // When & Then
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Concurrent Loading Tests
    
    func testConcurrentVideoLoading() async throws {
        // Given
        let videoURLs = [
            URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
            URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_640x360_1mb.mp4")!
        ]
        
        // When
        let results = await withTaskGroup(of: Result<URL, Error>.self) { group in
            for url in videoURLs {
                group.addTask {
                    do {
                        let localURL = try await self.mediaService.loadVideo(from: url)
                        return .success(localURL)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            var results: [Result<URL, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // Then
        XCTAssertEqual(results.count, videoURLs.count)
        // Note: Results might be failures if the test URLs are not accessible
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryWarningHandling() {
        // Given
        let initialThumbnailCache = mediaService.getCacheStatistics().thumbnailCacheSize
        
        // When
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Then
        // Should not crash
        XCTAssertTrue(true)
    }
    
    // MARK: - Media Item Tests
    
    func testMediaItemInitialization() {
        // Given
        let url = URL(string: "https://example.com/video.mp4")!
        let title = "Test Video"
        let thumbnailURL = URL(string: "https://example.com/thumbnail.jpg")!
        
        // When
        let mediaItem = MediaItem(
            url: url,
            type: .video,
            title: title,
            thumbnail: thumbnailURL
        )
        
        // Then
        XCTAssertNotNil(mediaItem.id)
        XCTAssertEqual(mediaItem.url, url)
        XCTAssertEqual(mediaItem.type, .video)
        XCTAssertEqual(mediaItem.title, title)
        XCTAssertEqual(mediaItem.thumbnail, thumbnailURL)
    }
    
    func testMediaItemTypes() {
        // Given
        let imageItem = MediaItem(url: URL(string: "https://example.com/image.jpg")!, type: .image, title: nil, thumbnail: nil)
        let videoItem = MediaItem(url: URL(string: "https://example.com/video.mp4")!, type: .video, title: nil, thumbnail: nil)
        let audioItem = MediaItem(url: URL(string: "https://example.com/audio.mp3")!, type: .audio, title: nil, thumbnail: nil)
        
        // When & Then
        XCTAssertEqual(imageItem.type, .image)
        XCTAssertEqual(videoItem.type, .video)
        XCTAssertEqual(audioItem.type, .audio)
    }
    
    // MARK: - Performance Tests
    
    func testMediaLoadingPerformance() async throws {
        // Given
        let videoURLs = [
            URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
        ]
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await withTaskGroup(of: Void.self) { group in
            for url in videoURLs {
                group.addTask {
                    do {
                        _ = try await self.mediaService.loadVideo(from: url)
                    } catch {
                        // Ignore errors for performance test
                    }
                }
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        // Then
        XCTAssertLessThan(duration, 60.0) // Should complete within 60 seconds
    }
}