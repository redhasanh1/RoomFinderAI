import SwiftUI

struct LazyLoadingDemoView: View {
    @State private var selectedTab = 0
    @StateObject private var imageService = ImageLoadingService.shared
    @StateObject private var mediaService = MediaLoadingService.shared
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // Image Loading Demo
                imageLoadingDemo
                    .tabItem {
                        Label("Images", systemImage: "photo")
                    }
                    .tag(0)
                
                // Video Loading Demo  
                videoLoadingDemo
                    .tabItem {
                        Label("Videos", systemImage: "video")
                    }
                    .tag(1)
                
                // Statistics
                statisticsView
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
                    .tag(2)
            }
            .navigationTitle("Lazy Loading Demo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear Cache") {
                        clearAllCaches()
                    }
                }
            }
        }
    }
    
    private var imageLoadingDemo: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Basic Image Loading
                VStack(alignment: .leading, spacing: 8) {
                    Text("Basic Image Loading")
                        .font(.headline)
                    
                    CachedAsyncImage(
                        url: URL(string: "https://picsum.photos/300/200?random=1"),
                        size: CGSize(width: 300, height: 200)
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                // Image with Custom Placeholder
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Placeholder")
                        .font(.headline)
                    
                    CachedAsyncImage(
                        url: URL(string: "https://picsum.photos/300/200?random=2"),
                        size: CGSize(width: 300, height: 200)
                    ) { image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ZStack {
                            Color.blue.opacity(0.1)
                            VStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                // Image Grid
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image Grid")
                        .font(.headline)
                    
                    LazyImageGrid(
                        urls: sampleImageURLs,
                        columns: 3,
                        spacing: 8,
                        itemSize: CGSize(width: 100, height: 100)
                    )
                }
                
                // Different Sizes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Different Sizes")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        CachedAsyncImage(
                            url: URL(string: "https://picsum.photos/400/300?random=10"),
                            size: CGSize(width: 80, height: 80)
                        )
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        
                        CachedAsyncImage(
                            url: URL(string: "https://picsum.photos/400/300?random=10"),
                            size: CGSize(width: 120, height: 120)
                        )
                        .frame(width: 120, height: 120)
                        .cornerRadius(8)
                        
                        CachedAsyncImage(
                            url: URL(string: "https://picsum.photos/400/300?random=10"),
                            size: CGSize(width: 160, height: 160)
                        )
                        .frame(width: 160, height: 160)
                        .cornerRadius(8)
                    }
                }
                
                // Preload Test
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preload Test")
                        .font(.headline)
                    
                    Button("Preload Images") {
                        let urls = Array(20...30).map { URL(string: "https://picsum.photos/300/200?random=\($0)")! }
                        imageService.preloadImages(from: urls)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
    
    private var videoLoadingDemo: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Basic Video Player
                VStack(alignment: .leading, spacing: 8) {
                    Text("Basic Video Player")
                        .font(.headline)
                    
                    LazyVideoPlayer(
                        url: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4"),
                        showControls: true,
                        autoplay: false
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                // Video Thumbnail
                VStack(alignment: .leading, spacing: 8) {
                    Text("Video Thumbnail")
                        .font(.headline)
                    
                    VideoThumbnailView(
                        url: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_640x360_1mb.mp4"),
                        size: CGSize(width: 300, height: 200)
                    )
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Button(action: {}) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                    )
                }
                
                // Media Grid
                VStack(alignment: .leading, spacing: 8) {
                    Text("Media Grid")
                        .font(.headline)
                    
                    MediaGridView(
                        mediaItems: sampleMediaItems,
                        columns: 2,
                        spacing: 8,
                        itemSize: CGSize(width: 150, height: 150)
                    )
                }
                
                // Preload Videos
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preload Videos")
                        .font(.headline)
                    
                    Button("Preload Sample Videos") {
                        let urls = [
                            URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
                            URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_640x360_1mb.mp4")!
                        ]
                        mediaService.preloadVideos(from: urls)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
    
    private var statisticsView: some View {
        List {
            Section("Image Loading Statistics") {
                let imageStats = imageService.getCacheStatistics()
                StatRow(title: "Cache Hits", value: "\(imageStats.cacheHits)")
                StatRow(title: "Cache Misses", value: "\(imageStats.cacheMisses)")
                StatRow(title: "Total Downloads", value: "\(imageStats.totalDownloads)")
                StatRow(title: "Failed Downloads", value: "\(imageStats.failedDownloads)")
                StatRow(title: "Hit Rate", value: String(format: "%.1f%%", imageStats.hitRate * 100))
                StatRow(title: "Success Rate", value: String(format: "%.1f%%", imageStats.successRate * 100))
                StatRow(title: "Cache Size", value: "\(imageStats.cacheSize) bytes")
                StatRow(title: "Cached Items", value: "\(imageStats.cachedItemCount)")
            }
            
            Section("Media Loading Statistics") {
                let mediaStats = mediaService.getCacheStatistics()
                StatRow(title: "Cache Hits", value: "\(mediaStats.cacheHits)")
                StatRow(title: "Cache Misses", value: "\(mediaStats.cacheMisses)")
                StatRow(title: "Total Downloads", value: "\(mediaStats.totalDownloads)")
                StatRow(title: "Failed Downloads", value: "\(mediaStats.failedDownloads)")
                StatRow(title: "Hit Rate", value: String(format: "%.1f%%", mediaStats.hitRate * 100))
                StatRow(title: "Success Rate", value: String(format: "%.1f%%", mediaStats.successRate * 100))
                StatRow(title: "Cache Size", value: mediaStats.formattedCacheSize)
                StatRow(title: "Max Cache Size", value: mediaStats.formattedMaxCacheSize)
                StatRow(title: "Cache Utilization", value: String(format: "%.1f%%", mediaStats.cacheUtilization * 100))
            }
            
            Section("Actions") {
                Button("Clear Image Cache") {
                    imageService.clearCache()
                }
                .foregroundColor(.blue)
                
                Button("Clear Media Cache") {
                    mediaService.clearCache()
                }
                .foregroundColor(.blue)
                
                Button("Clear All Caches") {
                    clearAllCaches()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var sampleImageURLs: [URL] {
        return Array(1...12).map { URL(string: "https://picsum.photos/300/300?random=\($0)")! }
    }
    
    private var sampleMediaItems: [MediaItem] {
        return [
            MediaItem(
                url: URL(string: "https://picsum.photos/300/300?random=1")!,
                type: .image,
                title: "Sample Image 1",
                thumbnail: nil
            ),
            MediaItem(
                url: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!,
                type: .video,
                title: "Sample Video 1",
                thumbnail: nil
            ),
            MediaItem(
                url: URL(string: "https://picsum.photos/300/300?random=2")!,
                type: .image,
                title: "Sample Image 2",
                thumbnail: nil
            ),
            MediaItem(
                url: URL(string: "https://sample-videos.com/zip/10/mp3/SampleAudio_0.7mb.mp3")!,
                type: .audio,
                title: "Sample Audio 1",
                thumbnail: nil
            ),
            MediaItem(
                url: URL(string: "https://picsum.photos/300/300?random=3")!,
                type: .image,
                title: "Sample Image 3",
                thumbnail: nil
            ),
            MediaItem(
                url: URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_640x360_1mb.mp4")!,
                type: .video,
                title: "Sample Video 2",
                thumbnail: nil
            )
        ]
    }
    
    private func clearAllCaches() {
        imageService.clearCache()
        mediaService.clearCache()
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct LazyLoadingTestView: View {
    @State private var showLargeImages = false
    @State private var imageCount = 20
    
    var body: some View {
        NavigationView {
            VStack {
                VStack {
                    HStack {
                        Text("Image Count: \(imageCount)")
                        Spacer()
                        Stepper("", value: $imageCount, in: 1...100, step: 5)
                    }
                    
                    Toggle("Show Large Images", isOn: $showLargeImages)
                }
                .padding()
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                        ForEach(0..<imageCount, id: \.self) { index in
                            let size = showLargeImages ? CGSize(width: 300, height: 300) : CGSize(width: 150, height: 150)
                            let urlString = showLargeImages 
                                ? "https://picsum.photos/800/600?random=\(index)"
                                : "https://picsum.photos/300/300?random=\(index)"
                            
                            CachedAsyncImage(
                                url: URL(string: urlString),
                                size: size
                            )
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Performance Test")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct LazyLoadingMemoryTestView: View {
    @State private var images: [String] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                Button("Load 100 Images") {
                    loadImages()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                
                if isLoading {
                    ProgressView("Loading images...")
                        .padding()
                }
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                        ForEach(images, id: \.self) { imageURL in
                            CachedAsyncImage(
                                url: URL(string: imageURL),
                                size: CGSize(width: 150, height: 150)
                            )
                            .aspectRatio(1, contentMode: .fit)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Memory Test")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func loadImages() {
        isLoading = true
        images.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let newImages = Array(1...100).map { "https://picsum.photos/400/400?random=\($0)" }
            
            DispatchQueue.main.async {
                self.images = newImages
                self.isLoading = false
            }
        }
    }
}

#Preview {
    LazyLoadingDemoView()
}