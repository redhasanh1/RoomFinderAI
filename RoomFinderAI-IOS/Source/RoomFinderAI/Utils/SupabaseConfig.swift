import Foundation
import Supabase

// Legacy file - functionality moved to SupabaseClientProvider.swift
// This file exists only to satisfy Xcode project references

struct SupabaseConfig {
    static let url = URL(string: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as! String)!
    static let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as! String
    
    // Use SupabaseClientProvider.shared instead of this
    static let client = SupabaseClient(
        supabaseURL: url,
        supabaseKey: anonKey
    )
}