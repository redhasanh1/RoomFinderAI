# Build and Run Instructions - AI Negotiator Integration

The AI Negotiator module has been fully integrated into the RoomFinderAI iOS app. Follow these instructions to build and test the application.

## Quick Start

1. **Open the project in Xcode**:
   ```bash
   open RoomFinderAI-IOS/Project/RoomFinderAI.xcodeproj
   ```

2. **Configure OpenAI API Key** (required for live AI responses):
   - In Xcode: Target → Build Settings → add User-Defined setting `OPENAI_API_KEY` with your key
   - Or set scheme environment variable `OPENAI_API_KEY`
   - CLI build example:
     ```bash
     OPENAI_API_KEY=sk-your-key xcodebuild -project RoomFinderAI.xcodeproj -scheme RoomFinderAI build
     ```
   - Without a key, the app falls back to mock AI responses (`AppConfig.enableMockAI` path)

3. **Build and Run**:
   - Select your target device/simulator
   - Press `Cmd + R` or click the Run button
   - Wait for build completion

4. **Test AI Negotiator**:
   - Navigate to **Home** or **Listings** tab
   - Find any property listing
   - Tap the blue **"Negotiate"** button on any listing card
   - Watch the AI automatically start negotiation with market analysis

## What's Been Integrated

### ✅ Files Added/Updated

**AI Negotiator Module** (All files in `Features/Negotiator/`):
- `AINegotiatorView.swift` - Main chat interface
- `AINegotiatorViewModel.swift` - Business logic and state management  
- `AINegotiatorService.swift` - OpenAI integration and market analysis
- `NegotiationModels.swift` - Data models and API structures
- `NegotiatorConfig.swift` - Configuration and settings
- `MarketStats.swift` - Market data calculations

**Integration Points**:
- `ListingCardView.swift` - Added "Negotiate" button with navigation
- `Secrets.swift` - Added OpenAI API key configuration
- `RoomFinderAIApp.swift` - Supabase environment already configured

### ✅ Navigation Flow

1. **Home/Listings → Property → Negotiate**
   - Browse listings on Home tab or Listings tab
   - Each listing card now has a blue "Negotiate" button
   - Tap to launch AI Negotiator with pre-populated listing data

2. **Auto-Generated Parameters**:
   - `conversationId`: New UUID() for each negotiation
   - `budget`: $1200 (configurable default)
   - `userEmail`: "test-user@example.com" (stub for testing)

### ✅ Features Working

- **Market Data Analysis**: Fetches comparable properties from Supabase
- **AI Fallback**: Uses OpenAI for market estimates when DB data insufficient  
- **Real-time Messaging**: Listens for landlord replies via Supabase realtime
- **Smart Reply Analysis**: Detects acceptance, counter-offers, rejections
- **Automatic Responses**: Generates strategic counter-offers and negotiations
- **Chat Interface**: Professional messaging UI with typing indicators

## Testing Scenarios

### 1. **Basic Negotiation Flow**
- Open app → Home/Listings → tap "Negotiate" on any property
- **Expected**: Market stats load, AI sends first negotiation message
- **Verify**: Chat interface opens, first message appears within ~3 seconds

### 2. **Market Data Fallback** 
- Navigate to a property with limited comparable data
- **Expected**: AI generates realistic market estimates using OpenAI
- **Verify**: Market stats section shows "Source: AI estimate"

### 3. **Real-time Response (Manual Test)**
- Start a negotiation and note the `conversation_id` from logs
- In Supabase dashboard, manually insert a landlord reply:
   ```sql
   INSERT INTO messages (conversation_id, sender_email, content) 
   VALUES ('your-conversation-id', 'landlord@test.com', 'How about $1100?');
   ```
- **Expected**: AI detects reply within seconds, analyzes price, responds strategically
- **Verify**: New messages appear in chat UI automatically

### 4. **Simple Acceptance Test**
- Insert simple acceptance message: `'sure'` or `'ok'`
- **Expected**: AI recognizes acceptance, generates final confirmation message
- **Verify**: Deal completion detected and celebrated in UI

## Troubleshooting

### Build Issues

**"Cannot find AINegotiatorView in scope"**
- Solution: Clean Build Folder (`Cmd + Shift + K`), then rebuild

**"Missing OpenAI API response"**
- Solution: Verify API key is correctly set in `Secrets.swift`
- Check Xcode console for detailed error messages

### Runtime Issues

**No market data loading**
- Check: Supabase connection in Xcode console
- Verify: Listings table has data with city/price/bedrooms fields

**AI not responding to messages**
- Check: OpenAI API key is valid and has sufficient credits
- Verify: Realtime subscription active in Supabase logs

**Navigation doesn't work**
- Check: NavigationView properly wraps parent screens
- Verify: Both Home and Listings screens use proper navigation

## Database Requirements

The app expects these Supabase tables:

```sql
-- Listings (should already exist)
CREATE TABLE listings (
  id uuid PRIMARY KEY,
  title text,
  price int4,
  city text,
  house_type text,
  bedrooms int4,
  description text,
  created_at timestamptz DEFAULT now(),
  media jsonb
);

-- Messages (for real-time negotiation)
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  sender_email text NOT NULL,
  role text DEFAULT 'user',
  content text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Enable realtime
ALTER publication supabase_realtime ADD TABLE messages;

-- RLS policies (for testing)
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_read_messages" ON messages FOR SELECT TO anon USING (true);
CREATE POLICY "anon_insert_messages" ON messages FOR INSERT TO anon WITH CHECK (true);
```

## Production Notes

- **API Key Security**: Move OpenAI key to Xcode build settings or CI/CD secrets
- **User Authentication**: Replace stub email with actual authenticated user
- **Budget Configuration**: Add user preference for default budget
- **Error Handling**: Monitor OpenAI rate limits and API costs
- **Analytics**: Track negotiation success rates and user engagement

---

**Ready to test!** Open `RoomFinderAI.xcodeproj` in Xcode, run on simulator, and tap "Negotiate" on any listing to see the AI Negotiator in action.