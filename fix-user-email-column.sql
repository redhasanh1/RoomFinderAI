-- CRITICAL FIX: Add missing user_email column to listings table
-- This column is essential for the listing update authorization to work
-- RUN THIS IN YOUR SUPABASE SQL EDITOR

-- Step 1: Add the user_email column
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS user_email VARCHAR(255);

-- Step 2: Create index for performance
CREATE INDEX IF NOT EXISTS idx_listings_user_email ON listings(user_email);

-- Step 3: Add a comment to document this column
COMMENT ON COLUMN listings.user_email IS 'Email of the user who created/owns this listing - used for authorization';

-- Step 4: You will need to manually update existing listings with their owner emails
-- For now, you can set a default email or update them one by one:
-- UPDATE listings SET user_email = 'default@example.com' WHERE user_email IS NULL;

-- Verification query to check the column was added:
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'listings' AND column_name = 'user_email';
