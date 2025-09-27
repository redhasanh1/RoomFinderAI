-- RoomPal Database Schema for Roommate Profiles
-- This file contains the database schema for storing roommate profile data

-- Create roommate_profiles table
CREATE TABLE IF NOT EXISTS roommate_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Basic Information
    name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100),
    age INTEGER CHECK (age >= 18 AND age <= 100),
    occupation VARCHAR(200),
    company VARCHAR(200),
    location VARCHAR(300),
    bio TEXT,

    -- Photos and Media
    avatar_url TEXT,
    photos JSONB DEFAULT '[]', -- Array of photo objects: [{"url": "...", "type": "main|hobby|lifestyle", "caption": "..."}]

    -- Personal Information (JSON structure)
    personal_info JSONB DEFAULT '{
        "education": "",
        "religion": "",
        "politicalViews": "",
        "languages": [],
        "zodiacSign": "",
        "height": "",
        "relationshipStatus": "",
        "lookingFor": ""
    }',

    -- Lifestyle Preferences (JSON structure)
    lifestyle JSONB DEFAULT '{
        "exercise": "",
        "diet": "",
        "drinking": "",
        "smoking": "",
        "pets": "",
        "sleepSchedule": "",
        "workSchedule": ""
    }',

    -- Hobbies and Interests (JSON array)
    hobbies JSONB DEFAULT '[]', -- [{"name": "Gaming", "icon": "🎮", "category": "entertainment"}]

    -- Compatibility Scores and Preferences
    compatibility_scores JSONB DEFAULT '{
        "cleanliness": 7,
        "socialLevel": 5,
        "noiseLevel": 5,
        "guestPolicy": 5,
        "organizationStyle": 5,
        "communicationStyle": 5,
        "kitchenUsage": 5,
        "sharedMeals": 3,
        "commonAreaUsage": 5,
        "smokingPolicy": 1,
        "petPolicy": 5,
        "dealBreakers": []
    }',

    -- Profile Status
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    profile_completed BOOLEAN DEFAULT false,

    -- Matching Preferences
    preferred_age_min INTEGER DEFAULT 18,
    preferred_age_max INTEGER DEFAULT 35,
    preferred_location_radius INTEGER DEFAULT 25, -- miles
    budget_min INTEGER,
    budget_max INTEGER,

    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_active TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create matches table for storing user interactions
CREATE TABLE IF NOT EXISTS roommate_matches (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    target_profile_id UUID REFERENCES roommate_profiles(id) ON DELETE CASCADE,

    -- Match data
    action VARCHAR(20) NOT NULL CHECK (action IN ('like', 'pass', 'super_like')),
    compatibility_score DECIMAL(5,2),
    is_mutual BOOLEAN DEFAULT false,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ensure one action per user-target pair
    UNIQUE(user_id, target_profile_id)
);

-- Create conversations table for matched users
CREATE TABLE IF NOT EXISTS roommate_conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    match_id UUID REFERENCES roommate_matches(id) ON DELETE CASCADE,
    user1_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user2_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Conversation metadata
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create messages table
CREATE TABLE IF NOT EXISTS roommate_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID REFERENCES roommate_conversations(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Message content
    content TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'system')),

    -- Message status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,

    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_roommate_profiles_user_id ON roommate_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_roommate_profiles_active ON roommate_profiles(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_roommate_profiles_location ON roommate_profiles(location);
CREATE INDEX IF NOT EXISTS idx_roommate_profiles_age ON roommate_profiles(age);
CREATE INDEX IF NOT EXISTS idx_roommate_matches_user_id ON roommate_matches(user_id);
CREATE INDEX IF NOT EXISTS idx_roommate_matches_target ON roommate_matches(target_profile_id);
CREATE INDEX IF NOT EXISTS idx_roommate_matches_mutual ON roommate_matches(is_mutual) WHERE is_mutual = true;

-- Row Level Security (RLS) Policies
ALTER TABLE roommate_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roommate_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE roommate_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE roommate_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for roommate_profiles
CREATE POLICY "Users can view active profiles" ON roommate_profiles
    FOR SELECT USING (is_active = true);

CREATE POLICY "Users can manage their own profile" ON roommate_profiles
    FOR ALL USING (auth.uid() = user_id);

-- RLS Policies for roommate_matches
CREATE POLICY "Users can view their own matches" ON roommate_matches
    FOR ALL USING (auth.uid() = user_id);

-- RLS Policies for conversations
CREATE POLICY "Users can access their conversations" ON roommate_conversations
    FOR ALL USING (auth.uid() = user1_id OR auth.uid() = user2_id);

-- RLS Policies for messages
CREATE POLICY "Users can access messages in their conversations" ON roommate_messages
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM roommate_conversations
            WHERE id = conversation_id
            AND (user1_id = auth.uid() OR user2_id = auth.uid())
        )
    );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_roommate_profiles_updated_at
    BEFORE UPDATE ON roommate_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_roommate_conversations_updated_at
    BEFORE UPDATE ON roommate_conversations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate compatibility score
CREATE OR REPLACE FUNCTION calculate_compatibility_score(
    profile1_id UUID,
    profile2_id UUID
) RETURNS DECIMAL(5,2) AS $$
DECLARE
    profile1 RECORD;
    profile2 RECORD;
    total_score DECIMAL(5,2) := 0;
    factor_count INTEGER := 0;
BEGIN
    -- Get both profiles
    SELECT * INTO profile1 FROM roommate_profiles WHERE id = profile1_id;
    SELECT * INTO profile2 FROM roommate_profiles WHERE id = profile2_id;

    -- Calculate compatibility based on various factors
    -- Sleep schedule compatibility (weight: 20%)
    IF (profile1.compatibility_scores->>'sleepSchedule')::INTEGER IS NOT NULL
       AND (profile2.compatibility_scores->>'sleepSchedule')::INTEGER IS NOT NULL THEN
        total_score := total_score + (10 - ABS((profile1.compatibility_scores->>'sleepSchedule')::INTEGER - (profile2.compatibility_scores->>'sleepSchedule')::INTEGER)) * 2;
        factor_count := factor_count + 1;
    END IF;

    -- Cleanliness compatibility (weight: 15%)
    IF (profile1.compatibility_scores->>'cleanliness')::INTEGER IS NOT NULL
       AND (profile2.compatibility_scores->>'cleanliness')::INTEGER IS NOT NULL THEN
        total_score := total_score + (10 - ABS((profile1.compatibility_scores->>'cleanliness')::INTEGER - (profile2.compatibility_scores->>'cleanliness')::INTEGER)) * 1.5;
        factor_count := factor_count + 1;
    END IF;

    -- Social level compatibility (weight: 15%)
    IF (profile1.compatibility_scores->>'socialLevel')::INTEGER IS NOT NULL
       AND (profile2.compatibility_scores->>'socialLevel')::INTEGER IS NOT NULL THEN
        total_score := total_score + (10 - ABS((profile1.compatibility_scores->>'socialLevel')::INTEGER - (profile2.compatibility_scores->>'socialLevel')::INTEGER)) * 1.5;
        factor_count := factor_count + 1;
    END IF;

    -- Add more compatibility factors as needed...

    -- Return average score as percentage
    IF factor_count > 0 THEN
        RETURN ROUND((total_score / factor_count), 2);
    ELSE
        RETURN 50.00; -- Default score if no factors available
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Sample data for testing (optional)
INSERT INTO roommate_profiles (
    user_id, name, last_name, age, occupation, company, location, bio,
    photos, personal_info, lifestyle, hobbies, compatibility_scores
) VALUES (
    gen_random_uuid(), -- This would be a real user_id in practice
    'Sarah',
    'Chen',
    22,
    'Computer Science Student',
    'UC Berkeley',
    'Berkeley, CA',
    'CS student who loves gaming, anime, and bubble tea. Looking for a study buddy and friend to share a place with!',
    '[
        {"url": "https://images.unsplash.com/photo-1494790108755-2616b612b5bc?w=400", "type": "main", "caption": "Profile photo"},
        {"url": "https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=400", "type": "hobby", "caption": "Gaming setup"},
        {"url": "https://images.unsplash.com/photo-1517816743773-6e0fd518b4a6?w=400", "type": "lifestyle", "caption": "Study space"}
    ]',
    '{
        "education": "UC Berkeley - Computer Science",
        "religion": "Buddhist",
        "politicalViews": "Liberal",
        "languages": ["English", "Mandarin", "Korean"],
        "zodiacSign": "Gemini",
        "height": "5''4\"",
        "relationshipStatus": "Single",
        "lookingFor": "Study Partner & Friend"
    }',
    '{
        "exercise": "Yoga & Hiking",
        "diet": "Vegetarian",
        "drinking": "Socially",
        "smoking": "Never",
        "pets": "Cat Person",
        "sleepSchedule": "Night Owl (11 PM - 7 AM)",
        "workSchedule": "Student (Flexible)"
    }',
    '[
        {"name": "Gaming", "icon": "🎮", "category": "entertainment"},
        {"name": "Coding", "icon": "💻", "category": "professional"},
        {"name": "Anime", "icon": "🎭", "category": "entertainment"},
        {"name": "K-Pop", "icon": "🎵", "category": "music"},
        {"name": "Bubble Tea", "icon": "🧋", "category": "food"},
        {"name": "Photography", "icon": "📸", "category": "creative"}
    ]',
    '{
        "cleanliness": 8,
        "socialLevel": 6,
        "noiseLevel": 4,
        "guestPolicy": 5,
        "organizationStyle": 7,
        "communicationStyle": 8,
        "kitchenUsage": 6,
        "sharedMeals": 4,
        "commonAreaUsage": 6,
        "smokingPolicy": 1,
        "petPolicy": 8,
        "dealBreakers": ["smoking", "excessive_partying"]
    }'
) ON CONFLICT DO NOTHING;