# AI Negotiator iOS Setup Guide

This guide explains how to set up and configure the AI Negotiator feature for the RoomFinderAI iOS app.

## Prerequisites

1. **OpenAI API Key**: You need a valid OpenAI API key to use the AI features
2. **Supabase Project**: Ensure your Supabase project has the required tables and RLS policies

## Configuration Steps

### 1. Add OpenAI API Key

Open `Source/RoomFinderAI/Config/Secrets.swift` and update the OpenAI configuration:

```swift
enum Secrets {
  // ... existing Supabase config ...
  
  // Replace with your actual OpenAI API key
  static let openAIKey = "sk-your-actual-openai-api-key-here"
  static let openAIOrgID: String? = nil // Optional: Add your org ID if needed
}
```

### 2. Database Setup

Run these SQL commands in your Supabase SQL editor to ensure the required tables exist:

```sql
-- Ensure messages table has the correct schema
CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  sender_email text NOT NULL,
  role text DEFAULT 'user',
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Allow anon users to read and insert messages
CREATE POLICY "anon_read_messages" ON public.messages 
  FOR SELECT TO anon USING (true);

CREATE POLICY "anon_insert_messages" ON public.messages 
  FOR INSERT TO anon WITH CHECK (true);

-- Enable realtime
ALTER publication supabase_realtime ADD TABLE public.messages;
```

### 3. Environment Variables (Optional)

For CI/CD or different environments, you can set these environment variables instead of hardcoding in Secrets.swift:

- `OPENAI_API_KEY`: Your OpenAI API key
- `OPENAI_ORG_ID`: Your OpenAI organization ID (optional)
- `OPENAI_MODEL`: Model to use (defaults to "gpt-4o-mini")

### 4. Build and Run

1. Open `RoomFinderAI.xcodeproj` in Xcode
2. Select your target device/simulator
3. Build and run the project

## Testing the AI Negotiator

### Manual Testing

1. Launch the app
2. Navigate to a property listing
3. Tap on "Start Negotiation" or similar button
4. The AI will:
   - Fetch market data for similar properties
   - Generate an initial negotiation message
   - Listen for landlord replies in real-time
   - Automatically respond based on the conversation context

### Test Scenarios

1. **Market Data Test**: 
   - Select properties in different locations
   - Verify market statistics appear correctly

2. **Negotiation Flow Test**:
   - Start a negotiation
   - In Supabase dashboard, manually insert a landlord reply:
   ```sql
   INSERT INTO messages (conversation_id, sender_email, content) 
   VALUES ('your-conversation-id', 'landlord@test.com', 'sure');
   ```
   - Verify the AI detects acceptance and responds appropriately

3. **Counter-Offer Test**:
   - Insert a counter-offer message:
   ```sql
   INSERT INTO messages (conversation_id, sender_email, content) 
   VALUES ('your-conversation-id', 'landlord@test.com', 'How about $1200?');
   ```
   - Verify the AI analyzes the price and responds strategically

## Features

### Web Parity

The iOS implementation maintains full feature parity with the web version:

- ✅ Real-time message listening via Supabase
- ✅ Market data analysis (database + AI fallback)
- ✅ Intelligent reply analysis with sentiment detection
- ✅ Strategic counter-offer generation
- ✅ Acceptance detection for simple responses ("sure", "ok", etc.)
- ✅ Variable temperature settings for different AI tasks
- ✅ Detailed prompts matching web implementation

### Key Differences from Web

1. **Email Configuration**: Uses `ai-negotiator@roomfinder.com` to match web
2. **Model**: Defaults to `gpt-4o-mini` (fast and cost-effective)
3. **Swift/SwiftUI**: Native iOS implementation with proper error handling
4. **Async/Await**: Modern Swift concurrency for all operations

## Troubleshooting

### OpenAI API Key Issues

If you see "Missing OpenAI API key" errors:
1. Verify the key is correctly set in Secrets.swift
2. Ensure the key starts with "sk-"
3. Check API key permissions on OpenAI dashboard

### Supabase Connection Issues

If messages aren't being sent/received:
1. Verify Supabase URL and anon key in Secrets.swift
2. Check RLS policies are correctly set
3. Ensure realtime is enabled for the messages table

### No Market Data

If market stats show as nil:
1. Check if there are listings in the database
2. Verify the AI fallback is working (needs valid OpenAI key)
3. Check network connectivity

## Security Notes

- **Never commit API keys**: Always use environment variables or secure storage
- **Use .gitignore**: Ensure Secrets.swift is in .gitignore if it contains real keys
- **Production Setup**: Use proper secret management (Xcode Cloud secrets, CI/CD env vars)

## Support

For issues or questions:
1. Check Xcode console for detailed error messages
2. Verify all configuration steps above
3. Test with the demo view if available
4. Check Supabase logs for database issues