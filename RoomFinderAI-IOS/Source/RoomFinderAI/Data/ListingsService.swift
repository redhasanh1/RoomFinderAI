import Supabase

struct ListingsService {
    let client = SupabaseClientProvider.shared

    func fetchListings(page: Int, pageSize: Int = 20, filters: ListingsFilter = .empty) async throws -> [Listing] {
        let offset = page * pageSize
        let end = offset + pageSize - 1

        var q = client.database
            .from("listings")
            // Include house_type and bedrooms since filters use them:
            .select("id,title,price,city,created_at,cover_image,category,house_type,bedrooms")

        // Apply SAME filters as website:
        if let s = filters.city, !s.isEmpty { q = q.ilike("city", pattern: "%\(s)%") }
        if let maxP = filters.maxPrice { q = q.lte("price", value: Double(maxP)) }
        if let minP = filters.minPrice { q = q.gte("price", value: Double(minP)) }
        if let ht = filters.houseType, !ht.isEmpty { q = q.eq("house_type", value: ht) }
        if let b = filters.bedrooms { q = q.eq("bedrooms", value: b) }
        if let search = filters.search, !search.isEmpty { q = q.ilike("title", pattern: "%\(search)%") }

        // ORDER + RANGE exactly like website:
        let listings: [Listing] = try await q
            .order("created_at", ascending: false)
            .range(from: offset, to: end)
            .execute()
            .value

        // DEBUG: dump raw JSON so we can see shape if decode fails
        #if DEBUG
        print("[RAW] listings count:", listings.count)
        if let first = listings.first {
            print("[RAW] first listing: id=\(first.id), title=\(first.title ?? "nil")")
        }
        #endif

        return listings
    }
}