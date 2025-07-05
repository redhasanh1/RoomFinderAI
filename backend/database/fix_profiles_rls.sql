-- Fix Row Level Security for profiles table

-- First, add missing columns to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS first_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS last_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS password VARCHAR(255);

-- Enable RLS if not already enabled
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Anyone can create a user account" ON profiles;

-- Create policies for profiles table
CREATE POLICY "Anyone can create a user account" ON profiles
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can view their own profile" ON profiles
    FOR SELECT USING (email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (email = current_setting('app.current_user_email', true));

-- Function to set current user email (if not exists)
CREATE OR REPLACE FUNCTION set_current_user_email(email TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_email', email, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;