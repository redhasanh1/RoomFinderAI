-- Migration: Add bathrooms column to listings table
-- Date: 2025-01-07
-- Purpose: Support bathroom count in property listings

-- Add bathrooms column if it doesn't exist
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS bathrooms NUMERIC(3,1) DEFAULT 1;

-- Update existing records to have a default value based on bedrooms
-- (Rough estimate: studio/1bed = 1 bath, 2bed = 1.5 bath, 3+bed = 2 bath)
UPDATE listings 
SET bathrooms = CASE 
    WHEN bedrooms <= 1 THEN 1
    WHEN bedrooms = 2 THEN 1.5
    WHEN bedrooms >= 3 THEN 2
    ELSE 1
END
WHERE bathrooms IS NULL;

-- Add comment to column
COMMENT ON COLUMN listings.bathrooms IS 'Number of bathrooms in the property (supports half baths as .5)';