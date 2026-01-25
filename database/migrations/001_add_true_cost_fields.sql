-- Migration: Add True Cost Calculator fields to listings table
-- Date: 2026-01-24
-- Description: Adds monthly cost breakdown fields to enable transparent pricing

-- Add new columns for cost breakdown
ALTER TABLE listings
ADD COLUMN IF NOT EXISTS utilities_cost DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS internet_cost DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS parking_fee DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS pet_fee DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS amenity_fees DECIMAL(10, 2),
ADD COLUMN IF NOT EXISTS renters_insurance DECIMAL(10, 2);

-- Add comments to document fields
COMMENT ON COLUMN listings.utilities_cost IS 'Monthly utilities cost (electricity, water, gas, trash) in USD';
COMMENT ON COLUMN listings.internet_cost IS 'Monthly internet/WiFi cost in USD';
COMMENT ON COLUMN listings.parking_fee IS 'Monthly parking fee in USD (0 if included)';
COMMENT ON COLUMN listings.pet_fee IS 'Monthly pet rent/fee in USD';
COMMENT ON COLUMN listings.amenity_fees IS 'Monthly amenity fees (gym, pool, etc.) in USD';
COMMENT ON COLUMN listings.renters_insurance IS 'Monthly renters insurance cost in USD';

-- Create index for filtering by total cost (computed)
CREATE INDEX IF NOT EXISTS idx_listings_total_cost ON listings (
    (COALESCE(price, 0) +
     COALESCE(utilities_cost, 0) +
     COALESCE(internet_cost, 0) +
     COALESCE(parking_fee, 0) +
     COALESCE(pet_fee, 0) +
     COALESCE(amenity_fees, 0) +
     COALESCE(renters_insurance, 0))
);

-- Create view for easy querying of total costs
CREATE OR REPLACE VIEW listings_with_total_cost AS
SELECT
    *,
    (COALESCE(price, 0) +
     COALESCE(utilities_cost, 0) +
     COALESCE(internet_cost, 0) +
     COALESCE(parking_fee, 0) +
     COALESCE(pet_fee, 0) +
     COALESCE(amenity_fees, 0) +
     COALESCE(renters_insurance, 0)) AS total_monthly_cost
FROM listings;

COMMENT ON VIEW listings_with_total_cost IS 'Listings with computed total monthly cost including all fees';
