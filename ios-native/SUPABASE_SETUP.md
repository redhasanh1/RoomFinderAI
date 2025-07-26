# Supabase Configuration Guide

This guide will help you set up Supabase for the RoomFinderAI iOS app.

## Prerequisites

- Supabase account ([supabase.com](https://supabase.com))
- Access to your existing RoomFinderAI database
- Basic understanding of SQL and PostgreSQL

## Step 1: Create or Access Your Supabase Project

1. **If you have an existing project:**
   - Go to [Supabase Dashboard](https://supabase.com/dashboard)
   - Select your RoomFinderAI project

2. **If creating a new project:**
   - Click "New Project"
   - Choose organization and region
   - Set database password
   - Wait for project creation

## Step 2: Get Your Project Credentials

1. Go to **Settings** → **API**
2. Copy the following values:
   - **Project URL**: `https://your-project-ref.supabase.co`
   - **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

3. Update your iOS app's `Constants.swift`:
   ```swift
   static let supabaseURL = "https://your-project-ref.supabase.co"
   static let supabaseAnonKey = "your-anon-key-here"
   ```

## Step 3: Database Schema Setup

### Required Tables

The following tables should already exist in your database. If not, run the SQL from your `database/migrations/` folder:

#### 1. Users/Profiles Table
```sql
CREATE TABLE profiles (
    id UUID REFERENCES auth.users PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    name TEXT,
    avatar TEXT,
    phone TEXT,
    location TEXT,
    preferences JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    verification_status TEXT DEFAULT 'pending',
    subscription_status TEXT DEFAULT 'free'
);
```

#### 2. Listings Table
```sql
CREATE TABLE listings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    location JSONB NOT NULL,
    bedrooms INTEGER NOT NULL,
    bathrooms INTEGER NOT NULL,
    square_footage DECIMAL(10,2),
    property_type TEXT NOT NULL,
    amenities TEXT[],
    images TEXT[],
    available_date DATE,
    lease_term INTEGER,
    pet_policy TEXT,
    smoking_policy TEXT,
    utilities JSONB,
    contact_info JSONB,
    landlord_id UUID REFERENCES profiles(id),
    status TEXT DEFAULT 'active',
    features TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    view_count INTEGER DEFAULT 0,
    favorite_count INTEGER DEFAULT 0
);
```

#### 3. Conversations Table
```sql
CREATE TABLE conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT,
    participants UUID[],
    listing_id UUID REFERENCES listings(id),
    last_message UUID,
    unread_count INTEGER DEFAULT 0,
    is_group_chat BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'active'
);
```

#### 4. Messages Table
```sql
CREATE TABLE messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    chat_id UUID REFERENCES conversations(id),
    sender_id UUID REFERENCES profiles(id),
    sender_name TEXT,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    attachments JSONB,
    reply_to UUID,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    edited_at TIMESTAMP WITH TIME ZONE,
    is_read BOOLEAN DEFAULT false,
    is_delivered BOOLEAN DEFAULT false,
    reactions JSONB
);
```

#### 5. AI Chats Table
```sql
CREATE TABLE ai_chats (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id),
    title TEXT NOT NULL,
    messages JSONB,
    context JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'active'
);
```

#### 6. Favorites Table
```sql
CREATE TABLE favorites (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id),
    listing_id UUID REFERENCES listings(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, listing_id)
);
```

## Step 4: Row Level Security (RLS)

Enable RLS on all tables for security:

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites ENABLE ROW LEVEL SECURITY;
```

### RLS Policies

#### Profiles Policies
```sql
-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);
```

#### Listings Policies
```sql
-- Anyone can view active listings
CREATE POLICY "Anyone can view active listings" ON listings
    FOR SELECT USING (status = 'active');

-- Landlords can insert their own listings
CREATE POLICY "Landlords can insert own listings" ON listings
    FOR INSERT WITH CHECK (auth.uid() = landlord_id);

-- Landlords can update their own listings
CREATE POLICY "Landlords can update own listings" ON listings
    FOR UPDATE USING (auth.uid() = landlord_id);
```

#### Conversations Policies
```sql
-- Users can view conversations they participate in
CREATE POLICY "Users can view own conversations" ON conversations
    FOR SELECT USING (auth.uid() = ANY(participants));

-- Users can insert conversations they participate in
CREATE POLICY "Users can insert own conversations" ON conversations
    FOR INSERT WITH CHECK (auth.uid() = ANY(participants));

-- Users can update conversations they participate in
CREATE POLICY "Users can update own conversations" ON conversations
    FOR UPDATE USING (auth.uid() = ANY(participants));
```

#### Messages Policies
```sql
-- Users can view messages in their conversations
CREATE POLICY "Users can view messages in own conversations" ON messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE conversations.id = messages.chat_id 
            AND auth.uid() = ANY(conversations.participants)
        )
    );

-- Users can insert messages in their conversations
CREATE POLICY "Users can insert messages in own conversations" ON messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM conversations 
            WHERE conversations.id = messages.chat_id 
            AND auth.uid() = ANY(conversations.participants)
        )
    );
```

#### AI Chats Policies
```sql
-- Users can view their own AI chats
CREATE POLICY "Users can view own AI chats" ON ai_chats
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own AI chats
CREATE POLICY "Users can insert own AI chats" ON ai_chats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own AI chats
CREATE POLICY "Users can update own AI chats" ON ai_chats
    FOR UPDATE USING (auth.uid() = user_id);
```

#### Favorites Policies
```sql
-- Users can view their own favorites
CREATE POLICY "Users can view own favorites" ON favorites
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own favorites
CREATE POLICY "Users can insert own favorites" ON favorites
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can delete their own favorites
CREATE POLICY "Users can delete own favorites" ON favorites
    FOR DELETE USING (auth.uid() = user_id);
```

## Step 5: Real-time Setup

Enable real-time for live chat functionality:

1. Go to **Settings** → **API**
2. Scroll to **Real-time** section
3. Enable real-time for tables:
   - `messages`
   - `conversations`
   - `ai_chats`

## Step 6: Storage Setup (Optional)

If you need file storage for images:

1. Go to **Storage** in the dashboard
2. Create a new bucket named `property-images`
3. Set appropriate policies for image uploads

```sql
-- Allow users to upload images
CREATE POLICY "Users can upload images" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'property-images');

-- Allow anyone to view images
CREATE POLICY "Anyone can view images" ON storage.objects
    FOR SELECT USING (bucket_id = 'property-images');
```

## Step 7: Authentication Setup

1. Go to **Authentication** → **Settings**
2. Configure authentication providers:
   - **Email**: Enable email authentication
   - **Apple**: Enable Sign in with Apple (required for App Store)
   - **Google**: Optional, for additional sign-in options

3. **Email Templates**: Customize email templates for:
   - Confirm signup
   - Reset password
   - Email change confirmation

## Step 8: Test the Connection

1. Update your iOS app's `Constants.swift` with the correct credentials
2. Run the app
3. Try to sign up a new user
4. Check the Supabase dashboard to see if the user appears in the auth table

## Troubleshooting

### Common Issues

1. **Connection Error**: Verify URL and API key are correct
2. **Auth Error**: Check if email authentication is enabled
3. **RLS Error**: Ensure RLS policies are properly configured
4. **Real-time Error**: Verify real-time is enabled for the required tables

### Debug Steps

1. Check the **API** → **Logs** section in Supabase dashboard
2. Use the **SQL Editor** to test queries manually
3. Verify table structures match the expected schema
4. Test authentication flow in the dashboard

## Security Best Practices

1. **Never expose your service key** in client-side code
2. **Use RLS policies** to secure data access
3. **Validate all inputs** in your Swift code
4. **Use HTTPS only** for all API calls
5. **Implement proper error handling**

## Next Steps

After completing this setup:

1. Test all authentication flows
2. Verify data operations work correctly
3. Test real-time functionality
4. Set up monitoring and alerts
5. Plan for production deployment

For more information, visit the [Supabase Documentation](https://supabase.com/docs).