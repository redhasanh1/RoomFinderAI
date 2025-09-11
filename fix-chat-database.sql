-- ============================================
-- ROOMFINDERAI CHAT DATABASE FIX
-- ============================================
-- Run this script in your Supabase SQL Editor to fix chat functionality
-- This will create/update the required tables for conversations and messages

-- ============================================
-- STEP 1: Check Current Structure (for debugging)
-- ============================================
-- First, let's see what tables you currently have
-- (You can run this separately to check your current setup)

-- SELECT table_name, column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name IN ('conversations', 'messages')
-- ORDER BY table_name, ordinal_position;

-- ============================================
-- STEP 2: Create/Update Required Tables
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create or update conversations table with correct structure
CREATE TABLE IF NOT EXISTS conversations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id TEXT,
    listing_title TEXT,
    tenant_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    landlord_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ,
    last_read_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add any missing columns to conversations table
ALTER TABLE conversations 
ADD COLUMN IF NOT EXISTS listing_id TEXT,
ADD COLUMN IF NOT EXISTS listing_title TEXT,
ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS landlord_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create or update messages table with correct structure
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_email TEXT,
    recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    landlord_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    file_name TEXT,
    file_url TEXT,
    file_size INTEGER,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add any missing columns to messages table
ALTER TABLE messages
ADD COLUMN IF NOT EXISTS conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS sender_email TEXT,
ADD COLUMN IF NOT EXISTS recipient_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS landlord_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS file_name TEXT,
ADD COLUMN IF NOT EXISTS file_url TEXT,
ADD COLUMN IF NOT EXISTS file_size INTEGER,
ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;

-- ============================================
-- STEP 3: Create Performance Indexes
-- ============================================

-- Indexes for conversations table
CREATE INDEX IF NOT EXISTS idx_conversations_tenant ON conversations(tenant_id);
CREATE INDEX IF NOT EXISTS idx_conversations_landlord ON conversations(landlord_id);
CREATE INDEX IF NOT EXISTS idx_conversations_listing ON conversations(listing_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at DESC);

-- Indexes for messages table
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_recipient ON messages(recipient_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON messages(created_at DESC);

-- ============================================
-- STEP 4: Set Up Row Level Security (RLS)
-- ============================================

-- Enable RLS on both tables
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can access their conversations" ON conversations;
DROP POLICY IF EXISTS "Users can access messages in their conversations" ON messages;

-- Create RLS policies for conversations
CREATE POLICY "Users can access their conversations" ON conversations
FOR ALL USING (
    auth.uid() = tenant_id OR auth.uid() = landlord_id
);

-- Create RLS policies for messages
CREATE POLICY "Users can access messages in their conversations" ON messages
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM conversations 
        WHERE id = conversation_id 
        AND (auth.uid() = tenant_id OR auth.uid() = landlord_id)
    )
);

-- ============================================
-- STEP 5: Create Update Function for Timestamps
-- ============================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update conversations.updated_at
DROP TRIGGER IF EXISTS update_conversations_updated_at ON conversations;
CREATE TRIGGER update_conversations_updated_at 
BEFORE UPDATE ON conversations 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- STEP 6: Verification Queries
-- ============================================
-- Run these to verify the setup worked correctly:

-- Check table structures
SELECT 'conversations' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'conversations'
UNION ALL
SELECT 'messages' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'messages'
ORDER BY table_name, ordinal_position;

-- Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('conversations', 'messages');

-- ============================================
-- COMPLETION MESSAGE
-- ============================================
-- If you see results from the verification queries above,
-- your chat database is now properly configured!
-- 
-- Next steps:
-- 1. The chat panel should now load your existing conversations
-- 2. Messages sent via individual listings will appear in main chat panel
-- 3. Real-time chat functionality should work properly