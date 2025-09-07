# Database Migrations

## How to Apply Migrations to Supabase

### Migration: add_bathrooms_column.sql
**Date:** 2025-01-07  
**Purpose:** Adds the `bathrooms` column to the `listings` table to support bathroom count in property listings.

#### To apply this migration:

1. **Via Supabase Dashboard:**
   - Go to your Supabase project dashboard
   - Navigate to the SQL Editor
   - Copy the contents of `add_bathrooms_column.sql`
   - Paste and run the SQL script
   - Verify the column was added successfully

2. **Via Supabase CLI:**
   ```bash
   supabase db push --file database/migrations/add_bathrooms_column.sql
   ```

3. **Verification:**
   After running the migration, verify it worked:
   ```sql
   -- Check if column exists
   SELECT column_name, data_type 
   FROM information_schema.columns 
   WHERE table_name = 'listings' 
   AND column_name = 'bathrooms';
   ```

#### What this migration does:
- Adds a `bathrooms` column (NUMERIC 3,1) to support decimal values (e.g., 1.5 for one and a half bathrooms)
- Sets default value to 1 for new records
- Updates existing records with sensible defaults based on bedroom count
- Adds a descriptive comment to the column

#### Rollback (if needed):
```sql
ALTER TABLE listings DROP COLUMN IF EXISTS bathrooms;
```

## Migration History
| Date | Migration File | Description | Status |
|------|---------------|-------------|--------|
| 2025-01-07 | add_bathrooms_column.sql | Add bathrooms column to listings table | Pending |