# City/Country Migration Guide

## Overview
This migration splits the existing `city` field (format: "City, Country") into separate `city` and `country` columns.

## Before Migration
- Current format: `city = "Indianapolis, US"`
- Search issues: Complex pattern matching required

## After Migration  
- New format: `city = "Indianapolis"`, `country = "US"`
- Simple search: `city.ilike.*indianapolis*`

## Steps to Execute

### 1. Run the Migration SQL
Copy and paste the contents of `migration_add_country_column.sql` into your Supabase SQL Editor and execute it.

### 2. Verify Migration
Check a few records in your Supabase table editor to ensure:
- City field now contains only the city name
- Country field contains the country code
- No data was lost

### 3. Update Application Code
After confirming the migration worked, the application code will be automatically updated.

## Rollback (if needed)
If something goes wrong, you can rollback with:

```sql
-- Rollback: Combine city and country back to original format
UPDATE listings 
SET city = city || ', ' || country
WHERE country IS NOT NULL;

-- Remove country column
ALTER TABLE listings DROP COLUMN country;
```

## Example Data Transformation
```
Before: city = "Indianapolis, US"
After:  city = "Indianapolis", country = "US"

Before: city = "Toronto, CA" 
After:  city = "Toronto", country = "CA"
```