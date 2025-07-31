-- Fix RLS Policies for iOS App Access
-- This allows proper access for both anonymous and authenticated users

-- Step 1: Update listings policies to use auth.uid() instead of custom setting
ALTER TABLE listings DISABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can view listings" ON listings;
DROP POLICY IF EXISTS "Users can create their own listings" ON listings;
DROP POLICY IF EXISTS "Users can update their own listings" ON listings;
DROP POLICY IF EXISTS "Users can delete their own listings" ON listings;

-- Create new policies that work with Supabase Auth
-- Allow anyone (including anonymous) to view listings
CREATE POLICY "Public read access to listings" ON listings
    FOR SELECT USING (true);

-- Allow authenticated users to create listings
CREATE POLICY "Authenticated users can create listings" ON listings
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND
        user_email = auth.jwt() ->> 'email'
    );

-- Allow users to update their own listings
CREATE POLICY "Users can update own listings" ON listings
    FOR UPDATE USING (
        auth.uid() IS NOT NULL AND
        user_email = auth.jwt() ->> 'email'
    );

-- Allow users to delete their own listings
CREATE POLICY "Users can delete own listings" ON listings
    FOR DELETE USING (
        auth.uid() IS NOT NULL AND
        user_email = auth.jwt() ->> 'email'
    );

-- Re-enable RLS
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;

-- Step 2: Create profiles table linked to auth.users
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    first_name TEXT,
    last_name TEXT,
    profile_image TEXT DEFAULT 'https://via.placeholder.com/40',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone" ON profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Create trigger to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
    INSERT INTO public.profiles (id, email, first_name, last_name)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'first_name', ''),
        COALESCE(new.raw_user_meta_data->>'last_name', '')
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger the function every time a user is created
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Step 3: Update other tables to use auth.uid()
-- Update AI Chats
ALTER TABLE ai_chats DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own AI chats" ON ai_chats;
DROP POLICY IF EXISTS "Users can create their own AI chats" ON ai_chats;
DROP POLICY IF EXISTS "Users can update their own AI chats" ON ai_chats;
DROP POLICY IF EXISTS "Users can delete their own AI chats" ON ai_chats;

CREATE POLICY "Users can view own AI chats" ON ai_chats
    FOR SELECT USING (
        auth.uid() IS NOT NULL AND
        user_email = auth.jwt() ->> 'email'
    );

CREATE POLICY "Users can create own AI chats" ON ai_chats
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL AND
        user_email = auth.jwt() ->> 'email'
    );

CREATE POLICY "Users can update own AI chats" ON ai_chats
    FOR UPDATE USING (
        auth.uid() IS NOT NULL AND
        user_email = auth.jwt() ->> 'email'
    );

CREATE POLICY "Users can delete own AI chats" ON ai_chats
    FOR DELETE USING (
        auth.uid() IS NOT NULL AND
        user_email = auth.jwt() ->> 'email'
    );

ALTER TABLE ai_chats ENABLE ROW LEVEL SECURITY;

-- Step 4: Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Step 5: Test queries
-- This should return listings even for anonymous users
SELECT COUNT(*) as total_listings FROM listings;

-- Add some test data if needed
INSERT INTO listings (
    title, price, city, street, postal_code, 
    house_type, bedrooms, utilities, description, 
    user_email, media
) VALUES 
(
    'Test Downtown Apartment', 2500, 'Toronto', '123 King St W',
    'M5V 3A5', 'Apartment', 2, 'Included',
    'Beautiful downtown apartment with amazing views',
    'test@example.com', '[]'::jsonb
),
(
    'Cozy Studio Near University', 1500, 'Toronto', '456 College St',
    'M5T 1S7', 'Apartment', 0, 'Not included',
    'Perfect for students, close to campus',
    'test2@example.com', '[]'::jsonb
)
ON CONFLICT DO NOTHING;