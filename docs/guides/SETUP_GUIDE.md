# RoomFinderAI Setup Guide

## Quick Start

1. **Install Dependencies**
   ```bash
   npm install
   ```

2. **Configure Environment Variables**
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env and add your API keys (NEVER commit this file!)
   nano .env
   ```

3. **Validate Configuration**
   ```bash
   npm run validate
   ```

4. **Start the Server**
   ```bash
   npm start
   ```

5. **Access the Application**
   - Open http://localhost:3000 in your browser
   - Health check: http://localhost:3000/health
   - Service status: http://localhost:3000/api/service-status

## Configuration Priority

The application loads configuration in this order:
1. Environment variables (highest priority)
2. .env file
3. Default values (lowest priority)

## Required Services

### Minimum Requirements
- **Supabase**: Database and authentication
  - Create a project at https://supabase.com
  - Copy your project URL and anon key

### Optional Services
- **OpenAI**: AI negotiator features
- **Stripe**: Payment processing
- **Google Maps**: Enhanced map features (falls back to OpenStreetMap)
- **Brevo**: Email notifications
- **Azure**: ID verification

## Service Status

The application includes automatic service detection:
- Missing services are gracefully handled
- Features automatically disable if required services are unavailable
- Anonymous browsing is enabled by default
- Users see friendly messages when features are unavailable

## Troubleshooting

### Server Won't Start
1. Check if port 3000 is available
2. Run `npm run validate` to check configuration
3. Check server logs for specific errors

### Services Not Working
1. Visit `/api/service-status` to see which services are detected
2. Verify API keys are correct and not using default values
3. Check that API keys have proper permissions

### Database Issues
1. Ensure Supabase URL and key are correct
2. Check that database tables are created (see database/migrations/)
3. Verify Row Level Security (RLS) policies are configured

## Security Notes

- **NEVER** commit .env file to version control
- **NEVER** expose API keys in client-side code
- Use environment variables for all sensitive data
- Enable HTTPS in production
- Keep dependencies updated

## Production Deployment

For production deployment:
1. Set `NODE_ENV=production`
2. Use proper secrets management (e.g., Railway secrets, AWS Secrets Manager)
3. Enable HTTPS
4. Set up proper logging and monitoring
5. Configure rate limiting and security headers

## Available Scripts

- `npm start` - Start the production server
- `npm run dev` - Start development server
- `npm run validate` - Validate configuration
- `npm run setup` - Install dependencies and validate
- `npm run build` - Build frontend assets

## Support

For issues or questions:
1. Check the configuration validator output
2. Review server logs
3. Check browser console for client-side errors
4. Ensure all required services are properly configured