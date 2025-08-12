import Foundation
import SwiftUI

@MainActor
final class ListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var filters = ListingsFilter()
    @Published var hasMorePages = true
    
    private let listingsService = ListingsService()
    private let realtimeService = ListingsRealtime()
    private var currentPage = 0
    private let pageSize = 20
    
    private var debounceTimer: Timer?
    
    init() {
        startRealtime()
    }
    
    deinit {
        stopRealtime()
    }
    
    func loadInitial() async {
        currentPage = 0
        hasMorePages = true
        await loadListings(resetList: true)
    }
    
    func loadMore() async {
        guard !isLoadingMore && hasMorePages else { return }
        currentPage += 1
        await loadListings(resetList: false)
    }
    
    func apply(filters: ListingsFilter) async {
        self.filters = filters
        await loadInitial()
    }
    
    func refresh() async {
        await loadInitial()
    }
    
    private func loadListings(resetList: Bool) async {
        if resetList {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        
        error = nil
        
        do {
            let fetchedListings = try await listingsService.fetchListings(
                page: currentPage,
                pageSize: pageSize,
                filters: filters
            )
            
            if resetList {
                listings = fetchedListings
            } else {
                listings.append(contentsOf: fetchedListings)
            }
            
            hasMorePages = fetchedListings.count == pageSize
            
        } catch {
            self.error = error.localizedDescription
            print("Error loading listings: \(error)")
            
            await retryAfterDelay()
        }
        
        isLoading = false
        isLoadingMore = false
    }
    
    private func retryAfterDelay() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        do {
            let retryListings = try await listingsService.fetchListings(
                page: currentPage,
                pageSize: pageSize,
                filters: filters
            )
            
            if currentPage == 0 {
                listings = retryListings
            } else {
                listings.append(contentsOf: retryListings)
            }
            
            error = nil
        } catch {
            print("Retry failed: \(error)")
        }
    }
    
    private func startRealtime() {
        realtimeService.start { [weak self] change in
            Task { @MainActor in
                guard let self = self else { return }
                
                self.debounceTimer?.invalidate()
                self.debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { _ in
                    Task { @MainActor in
                        self.handleRealtimeChange(change)
                    }
                }
            }
        }
    }
    
    private func stopRealtime() {
        realtimeService.stop()
        debounceTimer?.invalidate()
    }
    
    private func handleRealtimeChange(_ change: RealtimeChange<Listing>) {
        switch change {
        case .insert(let listing):
            if !listings.contains(where: { $0.id == listing.id }) {
                if matchesCurrentFilters(listing) {
                    listings.insert(listing, at: 0)
                }
            }
            
        case .update(let listing):
            if let index = listings.firstIndex(where: { $0.id == listing.id }) {
                if matchesCurrentFilters(listing) {
                    listings[index] = listing
                } else {
                    listings.remove(at: index)
                }
            } else if matchesCurrentFilters(listing) {
                listings.insert(listing, at: 0)
            }
            
        case .delete(let listing):
            listings.removeAll { $0.id == listing.id }
        }
    }
    
    private func matchesCurrentFilters(_ listing: Listing) -> Bool {
        if let city = filters.city, !city.isEmpty {
            if !listing.city.localizedCaseInsensitiveContains(city) {
                return false
            }
        }
        
        if let minPrice = filters.minPrice {
            if listing.price < minPrice {
                return false
            }
        }
        
        if let maxPrice = filters.maxPrice {
            if listing.price > maxPrice {
                return false
            }
        }
        
        if let houseType = filters.houseType, !houseType.isEmpty {
            if listing.houseType != houseType {
                return false
            }
        }
        
        if let bedrooms = filters.bedrooms {
            if listing.bedrooms != bedrooms {
                return false
            }
        }
        
        if let search = filters.search, !search.isEmpty {
            if !listing.title.localizedCaseInsensitiveContains(search) {
                return false
            }
        }
        
        return true
    }
}