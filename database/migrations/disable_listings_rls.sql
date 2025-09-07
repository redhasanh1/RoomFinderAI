-- Disable RLS on listings table for application-level authentication
-- Date: 2025-01-07
-- Purpose: Our app handles authentication at the application level (backend API),
--          not at the database level, so RLS is preventing legitimate updates

-- Check current RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'listings';

-- Disable Row Level Security on listings table
ALTER TABLE listings DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies (cleanup)
DROP POLICY IF EXISTS "Public read access to listings" ON listings;
DROP POLICY IF EXISTS "Authenticated users can create listings" ON listings;
DROP POLICY IF EXISTS "Users can update own listings" ON listings;
DROP POLICY IF EXISTS "Users can delete own listings" ON listings;
DROP POLICY IF EXISTS "Anyone can view listings" ON listings;
DROP POLICY IF EXISTS "Users can create their own listings" ON listings;
DROP POLICY IF EXISTS "Users can update their own listings" ON listings;
DROP POLICY IF EXISTS "Users can delete their own listings" ON listings;
DROP POLICY IF EXISTS "Anyone can view all listings" ON listings;
DROP POLICY IF EXISTS "Anyone can create listings" ON listings;
DROP POLICY IF EXISTS "Users can update their own listings by email" ON listings;
DROP POLICY IF EXISTS "Users can delete their own listings by email" ON listings;

-- Verify RLS is disabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'listings';

-- The backend server.js will handle authorization by checking user_email matches