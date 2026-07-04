-- Roommate messaging tables used by RoomPal (frontend/js/roommate-api.js)

CREATE TABLE IF NOT EXISTS public.roommate_conversations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user1_id UUID NOT NULL,
    user2_id UUID NOT NULL,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user1_id, user2_id)
);

CREATE TABLE IF NOT EXISTS public.roommate_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id UUID NOT NULL REFERENCES public.roommate_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL,
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_roommate_messages_conversation ON public.roommate_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_roommate_conversations_users ON public.roommate_conversations(user1_id, user2_id);

ALTER TABLE public.roommate_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roommate_messages ENABLE ROW LEVEL SECURITY;
