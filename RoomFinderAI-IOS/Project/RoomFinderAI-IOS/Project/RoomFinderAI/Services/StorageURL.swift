import Foundation
import Supabase

enum StorageURL {
  /// Public bucket: builds a public URL without round-trip.
  static func publicURL(supabase: SupabaseClient, bucket: String, path: String) -> URL? {
    // If path is already a full URL, return it
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
      return URL(string: path)
    }
    
    let publicURLString = supabase.storage.from(bucket).getPublicURL(path: path)
    return URL(string: publicURLString)
  }

  /// Signed URL for private buckets (fallback). Expires in 1h.
  static func signedURL(supabase: SupabaseClient, bucket: String, path: String) async -> URL? {
    // If path is already a full URL, return it
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
      return URL(string: path)
    }
    
    do {
      let signed = try await supabase.storage.from(bucket).createSignedURL(path: path, expiresIn: 3600)
      return URL(string: signed.signedURL)
    } catch {
      print("SignedURL error:", error)
      return nil
    }
  }
}