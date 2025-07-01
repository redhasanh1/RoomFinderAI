-- Room Finder Database Schema and Policies

-- Enable Row Level Security extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    profile_image VARCHAR(500) DEFAULT 'https://via.placeholder.com/40',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Listings table (already referenced in listings.html)
CREATE TABLE IF NOT EXISTS listings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    price INTEGER NOT NULL,
    city VARCHAR(100) NOT NULL,
    street VARCHAR(255) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    house_type VARCHAR(50) NOT NULL CHECK (house_type IN ('House', 'Apartment', 'Condo', 'Townhouse')),
    bedrooms INTEGER NOT NULL CHECK (bedrooms >= 0),
    utilities VARCHAR(50) DEFAULT 'Not included' CHECK (utilities IN ('Included', 'Not included')),
    description TEXT,
    media JSONB DEFAULT '[]'::jsonb,
    user_email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
);

-- AI Chats table
CREATE TABLE IF NOT EXISTS ai_chats (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    conversation_data JSONB NOT NULL DEFAULT '[]'::jsonb,
    title VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
);

-- Conversations table (for user-to-user messaging)
CREATE TABLE IF NOT EXISTS conversations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id UUID NOT NULL,
    sender_email VARCHAR(255) NOT NULL,
    receiver_email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_email) REFERENCES users(email) ON DELETE CASCADE,
    FOREIGN KEY (receiver_email) REFERENCES users(email) ON DELETE CASCADE,
    UNIQUE(listing_id, sender_email, receiver_email)
);

-- Messages table
CREATE TABLE IF NOT EXISTS messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    conversation_id UUID NOT NULL,
    sender_email VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'text' CHECK (message_type IN ('text', 'file', 'lease')),
    file_url TEXT,
    file_name VARCHAR(255),
    file_size INTEGER,
    file_type VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_email) REFERENCES users(email) ON DELETE CASCADE
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_listings_user_email ON listings(user_email);
CREATE INDEX IF NOT EXISTS idx_listings_city ON listings(city);
CREATE INDEX IF NOT EXISTS idx_listings_price ON listings(price);
CREATE INDEX IF NOT EXISTS idx_listings_bedrooms ON listings(bedrooms);
CREATE INDEX IF NOT EXISTS idx_listings_created_at ON listings(created_at);
CREATE INDEX IF NOT EXISTS idx_ai_chats_user_email ON ai_chats(user_email);
CREATE INDEX IF NOT EXISTS idx_conversations_listing_id ON conversations(listing_id);
CREATE INDEX IF NOT EXISTS idx_conversations_sender ON conversations(sender_email);
CREATE INDEX IF NOT EXISTS idx_conversations_receiver ON conversations(receiver_email);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Row Level Security Policies

-- Users policies
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (email = current_setting('app.current_user_email', true));

CREATE POLICY "Anyone can create a user account" ON users
    FOR INSERT WITH CHECK (true);

-- Listings policies
CREATE POLICY "Anyone can view listings" ON listings
    FOR SELECT USING (true);

CREATE POLICY "Users can create their own listings" ON listings
    FOR INSERT WITH CHECK (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update their own listings" ON listings
    FOR UPDATE USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can delete their own listings" ON listings
    FOR DELETE USING (user_email = current_setting('app.current_user_email', true));

-- AI Chats policies
CREATE POLICY "Users can view their own AI chats" ON ai_chats
    FOR SELECT USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can create their own AI chats" ON ai_chats
    FOR INSERT WITH CHECK (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can update their own AI chats" ON ai_chats
    FOR UPDATE USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "Users can delete their own AI chats" ON ai_chats
    FOR DELETE USING (user_email = current_setting('app.current_user_email', true));

-- Conversations policies
CREATE POLICY "Users can view conversations they participate in" ON conversations
    FOR SELECT USING (
        sender_email = current_setting('app.current_user_email', true) OR 
        receiver_email = current_setting('app.current_user_email', true)
    );

CREATE POLICY "Users can create conversations" ON conversations
    FOR INSERT WITH CHECK (sender_email = current_setting('app.current_user_email', true));

-- Messages policies
CREATE POLICY "Users can view messages in their conversations" ON messages
    FOR SELECT USING (
        conversation_id IN (
            SELECT id FROM conversations 
            WHERE sender_email = current_setting('app.current_user_email', true) 
               OR receiver_email = current_setting('app.current_user_email', true)
        )
    );

CREATE POLICY "Users can send messages in their conversations" ON messages
    FOR INSERT WITH CHECK (
        sender_email = current_setting('app.current_user_email', true) AND
        conversation_id IN (
            SELECT id FROM conversations 
            WHERE sender_email = current_setting('app.current_user_email', true) 
               OR receiver_email = current_setting('app.current_user_email', true)
        )
    );

-- Function to set current user email (used by RLS)
CREATE OR REPLACE FUNCTION set_current_user_email(email TEXT)
RETURNS VOID AS $$
BEGIN
    PERFORM set_config('app.current_user_email', email, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- User Activities table
CREATE TABLE IF NOT EXISTS user_activities (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email VARCHAR(255) NOT NULL,
    activity_type VARCHAR(50) NOT NULL CHECK (activity_type IN ('registered', 'profile_updated', 'listing_created', 'subscription_bought', 'subscription_renewed', 'message_received', 'message_sent')),
    description TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_email) REFERENCES users(email) ON DELETE CASCADE
);

-- Index for user activities
CREATE INDEX IF NOT EXISTS idx_user_activities_user_email ON user_activities(user_email);
CREATE INDEX IF NOT EXISTS idx_user_activities_created_at ON user_activities(created_at);
CREATE INDEX IF NOT EXISTS idx_user_activities_type ON user_activities(activity_type);

-- User Activities policies
CREATE POLICY "Users can view their own activities" ON user_activities
    FOR SELECT USING (user_email = current_setting('app.current_user_email', true));

CREATE POLICY "System can create user activities" ON user_activities
    FOR INSERT WITH CHECK (true);

-- Enable Row Level Security for user_activities
ALTER TABLE user_activities ENABLE ROW LEVEL SECURITY;

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_listings_updated_at 
    BEFORE UPDATE ON listings 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ai_chats_updated_at 
    BEFORE UPDATE ON ai_chats 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();