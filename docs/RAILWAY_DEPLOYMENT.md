# Railway Deployment Guide for RoomFinderAI

## Quick Fix for OpenAI API 401 Error

The 401 authentication error occurs because the `OPENAI_API_KEY` environment variable is not set in Railway.

### Immediate Fix Steps:

1. **Go to Railway Dashboard**
   - Visit [railway.app](https://railway.app)
   - Navigate to your RoomFinderAI project

2. **Set Environment Variables**
   - Click on the **Variables** tab
   - Add the following required variables:

   ```
   OPENAI_API_KEY=sk-your-actual-openai-api-key-here
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-key
   ```

3. **Optional Variables** (for full functionality):
   ```
   OPENAI_ORG_ID=org-your-organization-id
   OPENAI_MODEL=gpt-3.5-turbo
   STRIPE_SECRET_KEY=sk_your-stripe-secret-key
   STRIPE_PUBLISHABLE_KEY=pk_your-stripe-publishable-key
   GOOGLE_API_KEY=your-google-api-key
   ```

4. **Redeploy**
   - After adding the variables, Railway will automatically redeploy
   - Or manually trigger a deployment

### Getting Your OpenAI API Key:

1. Visit [platform.openai.com](https://platform.openai.com)
2. Go to **API Keys** section
3. Create a new API key
4. Copy the key (starts with `sk-`)
5. Paste it into Railway's `OPENAI_API_KEY` variable

### Verification Steps:

1. **Check Logs**
   - In Railway dashboard, go to **Deployments** tab
   - Check the latest deployment logs for:
   ```
   ✅ Stripe initialized
   ✅ Supabase initialized
   📋 Config endpoint called - checking environment variables
   ```

2. **Test Configuration**
   - Visit your deployed app at: `https://your-app.railway.app/api/config`
   - Should return JSON with your configuration (API keys will be partially hidden)

3. **Test AI Negotiator**
   - Go to: `https://your-app.railway.app/ai-negotiator.html`
   - Should load without error messages
   - Try sending a test message

### Troubleshooting:

**If you still see 401 errors:**

1. **Verify API Key Format**
   - Must start with `sk-`
   - No extra spaces or newlines
   - Full key copied correctly

2. **Check OpenAI Account**
   - Ensure you have credits in your OpenAI account
   - Verify the API key hasn't been revoked
   - Check rate limits

3. **Railway Configuration**
   - Ensure variables are saved properly
   - Try redeploying manually
   - Check deployment logs for errors

**Debug Commands (local testing):**
```bash
# Test configuration locally
node test-openai.js

# Check environment
printenv | grep OPENAI
```

### Architecture Notes:

- Backend server loads environment variables in `/app/config.js`
- Frontend loads config via `/api/config` endpoint
- AI chat functionality is in `/app/ai-chat.js`
- All API calls include comprehensive error handling

### Security:

- API keys are never exposed to the frontend directly
- Environment variables are trimmed to remove newlines
- Configuration endpoint filters sensitive data appropriately