-- Add cached geocode coordinates to the listings table.
--
-- Motivation: the listings map currently runs N client-side Nominatim
-- geocodes per page load (one per listing). Nominatim throttles to ~1 req/s
-- and frequently rate-limits the browser, so markers fail to render. Caching
-- coordinates on the row turns map render into a single SELECT.
--
-- After this migration:
--   * /api/geocode/batch (backend) populates these columns using Google Geocoding
--   * fetchListings() in listings.html selects latitude/longitude alongside the row
--   * updateMap() uses the stored coords directly; only listings still missing
--     coords get sent to the batch endpoint, which writes the result back.
--
-- Safe to run multiple times (idempotent column adds + IF NOT EXISTS index).

ALTER TABLE listings
    ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS geocoded_at TIMESTAMPTZ;

-- Partial index: only rows that actually have coords. Supports both the
-- per-listing read path and future viewport bounding-box queries
-- (latitude BETWEEN ... AND ... + longitude BETWEEN ... AND ...).
CREATE INDEX IF NOT EXISTS idx_listings_lat_lng
    ON listings (latitude, longitude)
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

COMMENT ON COLUMN listings.latitude  IS 'Geocoded WGS84 latitude. Populated by /api/geocode (Google Maps) at write time. NULL means not yet geocoded.';
COMMENT ON COLUMN listings.longitude IS 'Geocoded WGS84 longitude. Populated by /api/geocode (Google Maps) at write time. NULL means not yet geocoded.';
COMMENT ON COLUMN listings.geocoded_at IS 'Timestamp of last successful geocode. Re-geocode if street/city/postalCode change.';
