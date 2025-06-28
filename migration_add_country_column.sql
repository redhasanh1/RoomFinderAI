-- Migration: Add country column to listings table
-- Run this in your Supabase SQL Editor

-- Step 1: Add country column
ALTER TABLE listings 
ADD COLUMN country VARCHAR(100) DEFAULT 'US';

-- Step 2: Update existing data by splitting city field
-- This will extract country from "City, Country" format
UPDATE listings 
SET 
    country = CASE 
        WHEN city LIKE '%,%' THEN TRIM(SPLIT_PART(city, ',', 2))
        ELSE 'US'  -- Default to US if no comma found
    END,
    city = CASE 
        WHEN city LIKE '%,%' THEN TRIM(SPLIT_PART(city, ',', 1))
        ELSE city  -- Keep original city if no comma
    END;

-- Step 3: Add index for better search performance
CREATE INDEX IF NOT EXISTS idx_listings_city_country ON listings(city, country);

-- Step 4: Verify the migration worked
SELECT city, country, title FROM listings LIMIT 10;