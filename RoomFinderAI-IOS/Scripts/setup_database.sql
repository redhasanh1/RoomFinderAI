-- RoomFinderAI Database Schema for Supabase
-- Run this in your Supabase SQL editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create users table (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    phone TEXT,
    avatar_url TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    subscription_status TEXT DEFAULT 'free',
    subscription_expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create listings table
CREATE TABLE IF NOT EXISTS public.listings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    price INTEGER NOT NULL,
    city TEXT NOT NULL,
    street TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    house_type TEXT NOT NULL,
    bedrooms INTEGER NOT NULL,
    utilities TEXT NOT NULL,
    media TEXT[] DEFAULT '{}',
    user_email TEXT NOT NULL,
    view_count INTEGER DEFAULT 0,
    available_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    pet_policy TEXT DEFAULT 'not_allowed',
    smoking_policy TEXT DEFAULT 'not_allowed',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create chats table
CREATE TABLE IF NOT EXISTS public.chats (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id UUID REFERENCES listings(id),
    participants TEXT[] NOT NULL,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    chat_id UUID REFERENCES chats(id),
    sender_email TEXT NOT NULL,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    attachments TEXT[] DEFAULT '{}',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create user_favorites table
CREATE TABLE IF NOT EXISTS public.user_favorites (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email TEXT NOT NULL,
    listing_id UUID REFERENCES listings(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_email, listing_id)
);

-- Create ai_negotiations table
CREATE TABLE IF NOT EXISTS public.ai_negotiations (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    listing_id UUID REFERENCES listings(id),
    user_email TEXT NOT NULL,
    initial_price INTEGER NOT NULL,
    final_price INTEGER,
    negotiation_status TEXT DEFAULT 'active',
    ai_responses JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_email TEXT NOT NULL,
    plan_type TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    stripe_subscription_id TEXT,
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert sample listings
INSERT INTO listings (title, description, price, city, street, postal_code, house_type, bedrooms, utilities, media, user_email) VALUES
('Modern Downtown Apartment', 'Beautiful 2BR apartment in the heart of downtown', 1200, 'Toronto', '123 King St W', 'M5V 1A1', 'apartment', 2, 'Heat, Water, Electricity included', '{"https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800", "https://images.unsplash.com/photo-1484154218962-a197022b5858?w=800"}', 'landlord@example.com'),
('Cozy Student Room', 'Perfect for students, close to university', 800, 'Toronto', '456 College St', 'M5S 2E5', 'room', 1, 'Internet, Utilities included', '{"https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800"}', 'student@example.com'),
('Spacious Family House', '4BR house with backyard, perfect for families', 2500, 'Toronto', '789 Elm Ave', 'M4K 1N2', 'house', 4, 'Tenant responsible for utilities', '{"https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=800", "https://images.unsplash.com/photo-1570129477492-45c003edd2be?w=800"}', 'family@example.com'),
('Luxury Condo', 'High-rise condo with amazing city views', 1800, 'Toronto', '321 Bay St', 'M5H 2R2', 'condo', 2, 'All utilities included', '{"https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=800"}', 'luxury@example.com'),
('Summer Sublease', 'Available for summer term, furnished', 600, 'Toronto', '654 Queen St E', 'M4M 1G4', 'sublease', 1, 'All inclusive', '{"https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800"}', 'summer@example.com'),
('Studio Apartment', 'Compact studio perfect for young professionals', 900, 'Toronto', '987 Yonge St', 'M4W 2H2', 'studio', 1, 'Heat and water included', '{"https://images.unsplash.com/photo-1449824913935-59a10b8d2000?w=800"}', 'studio@example.com'),
('Shared Townhouse', 'Room in beautiful townhouse, shared amenities', 700, 'Toronto', '147 Spadina Ave', 'M5T 2C2', 'townhouse', 3, 'Shared utilities', '{"https://images.unsplash.com/photo-1480074568708-e7b720bb3f09?w=800"}', 'shared@example.com'),
('Pet-Friendly Apartment', '2BR apartment that welcomes pets', 1400, 'Toronto', '258 Bloor St W', 'M5S 1V8', 'apartment', 2, 'Heat included', '{"https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=800"}', 'petfriendly@example.com');

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_negotiations ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Create policies for listings (public read, authenticated write)
CREATE POLICY "Listings are viewable by everyone" ON listings FOR SELECT USING (true);
CREATE POLICY "Users can insert their own listings" ON listings FOR INSERT WITH CHECK (auth.email() = user_email);
CREATE POLICY "Users can update their own listings" ON listings FOR UPDATE USING (auth.email() = user_email);
CREATE POLICY "Users can delete their own listings" ON listings FOR DELETE USING (auth.email() = user_email);

-- Create policies for users
CREATE POLICY "Users can view their own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON users FOR UPDATE USING (auth.uid() = id);

-- Create policies for chats
CREATE POLICY "Users can view their own chats" ON chats FOR SELECT USING (auth.email() = ANY(participants));
CREATE POLICY "Users can create chats" ON chats FOR INSERT WITH CHECK (auth.email() = ANY(participants));

-- Create policies for messages
CREATE POLICY "Users can view messages in their chats" ON messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM chats WHERE chats.id = messages.chat_id AND auth.email() = ANY(chats.participants)
    )
);
CREATE POLICY "Users can send messages to their chats" ON messages FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM chats WHERE chats.id = messages.chat_id AND auth.email() = ANY(chats.participants)
    )
);

-- Create policies for favorites
CREATE POLICY "Users can manage their own favorites" ON user_favorites FOR ALL USING (auth.email() = user_email);

-- Create policies for AI negotiations
CREATE POLICY "Users can view their own negotiations" ON ai_negotiations FOR SELECT USING (auth.email() = user_email);
CREATE POLICY "Users can create negotiations" ON ai_negotiations FOR INSERT WITH CHECK (auth.email() = user_email);
CREATE POLICY "Users can update their own negotiations" ON ai_negotiations FOR UPDATE USING (auth.email() = user_email);

-- Create policies for subscriptions
CREATE POLICY "Users can view their own subscriptions" ON subscriptions FOR SELECT USING (auth.email() = user_email);
CREATE POLICY "Users can manage their own subscriptions" ON subscriptions FOR ALL USING (auth.email() = user_email);

-- Create functions for updated_at triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_listings_updated_at BEFORE UPDATE ON listings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_chats_updated_at BEFORE UPDATE ON chats FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_ai_negotiations_updated_at BEFORE UPDATE ON ai_negotiations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();