# 🏠 AI Negotiator - RoomFinder Platform

An advanced AI-powered rental negotiation platform with sophisticated market intelligence and real-time communication.

## 🚀 Features

### **AI Negotiation Engine**
- **Advanced Market Intelligence**: Dynamic pricing models with seasonal adjustments
- **Personality Detection**: Adapts communication style to landlord personality
- **Progressive Negotiation**: Multi-round strategy with success tracking
- **Real-time Updates**: Live chat with automatic polling and WebSocket support
- **Meeting Coordination**: Smart scheduling and logistics management

### **Platform Features**
- **Rental Listings**: Browse and search properties
- **User Authentication**: Secure login/registration system
- **Payment Processing**: Stripe integration for subscriptions
- **Market Analysis**: Automated price predictions and market data
- **External Integration**: Kijiji and Facebook Marketplace URL generation

## 🛠️ Technology Stack

- **Frontend**: Vanilla JavaScript, HTML5, CSS3, Tailwind CSS
- **Backend**: Node.js, Express.js
- **Database**: Supabase (PostgreSQL)
- **AI Integration**: OpenAI GPT-3.5/4
- **Payment**: Stripe API
- **Maps**: Google Maps API
- **Real-time**: Supabase Real-time subscriptions

## 📦 Installation

### Prerequisites
- Node.js 16+ 
- npm or yarn
- Supabase account
- OpenAI API key
- Stripe account
- Google Maps API key

### Local Development

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd roomfinder-ai
```

2. **Install dependencies**
```bash
# Root dependencies
npm install

# Backend dependencies
cd backend
npm install
cd ..
```

3. **Configuration**
```bash
# Decrypt the config file (password: nibsaregood)
python decrypt_config.py

# Or create your own config.js with:
# - OPENAI_API_KEY
# - SUPABASE_URL 
# - SUPABASE_ANON_KEY
# - STRIPE_SECRET_KEY
# - STRIPE_PUBLISHABLE_KEY
# - GOOGLE_API_KEY
```

4. **Database Setup**
```bash
# Run the SQL schema files in Supabase:
# - database_schema.sql
# - create_subscriptions_table.sql
# - fix_ai_chats_rls.sql
```

5. **Start the server**
```bash
node backend/server.js
```

## 🚀 Railway Deployment

### Step 1: Prepare Repository

1. **Initialize Git Repository**
```bash
git init
git add .
git commit -m "Initial commit - AI Negotiator Platform"
```

2. **Push to GitHub**
```bash
# Create a new repository on GitHub
git remote add origin https://github.com/yourusername/roomfinder-ai.git
git branch -M main
git push -u origin main
```

### Step 2: Deploy to Railway

1. **Visit Railway.app**
   - Go to [railway.app](https://railway.app)
   - Sign up/Login with GitHub

2. **Create New Project**
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository

3. **Environment Variables (AUTO-CONFIGURED)**
   ✨ **No manual setup needed!** The encrypted config.js file is automatically decrypted on startup.
   
   Optional: Override with Railway environment variables if needed:
   ```
   CONFIG_PASSWORD=nibsaregood  # (optional - default password used)
   ```

4. **Deploy**
   - Railway will automatically detect the configuration
   - Build and deploy process will start
   - Your app will be available at the provided URL

## 🔧 Configuration

### Environment Variables
The application requires these environment variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `OPENAI_API_KEY` | OpenAI API key for AI negotiation | Yes |
| `SUPABASE_URL` | Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase anonymous key | Yes |
| `STRIPE_SECRET_KEY` | Stripe secret key | Yes |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key | Yes |
| `GOOGLE_API_KEY` | Google Maps API key | Yes |
| `PORT` | Server port (auto-set by Railway) | No |

### Database Schema
The application uses these main tables:
- `profiles` - User profiles
- `listings` - Rental listings
- `messages` - Chat messages
- `conversations` - Chat conversations
- `ai_chats` - AI negotiation notifications
- `subscriptions` - User subscriptions
- `negotiation_outcomes` - ML training data

## 🎯 API Endpoints

### Authentication
- `POST /api/register` - User registration
- `POST /api/login` - User login

### Listings
- `GET /api/listings` - Get all listings
- `POST /api/listings` - Create new listing
- `GET /api/listings/:id` - Get listing by ID

### AI Features
- `POST /api/ai-negotiator` - AI chat endpoint
- `POST /api/predict/kijiji` - Generate Kijiji URLs
- `POST /api/predict/marketplace` - Generate Marketplace URLs

### Payments
- `POST /api/process-payment` - Process Stripe payments
- `GET /api/subscription/:email` - Get user subscription

## 🧠 AI Negotiation Features

### Advanced Capabilities
- **Dynamic Market Pricing**: Real-time market analysis with seasonal adjustments
- **Personality Adaptation**: Detects landlord communication style and adapts accordingly
- **Progressive Strategies**: Different tactics for each negotiation round
- **Success Tracking**: Machine learning from previous negotiations
- **Meeting Coordination**: Smart scheduling and logistics management

### Response Variety
- 40+ unique response templates
- Anti-repetition system with 80% similarity detection
- Context-aware conversation state management
- Professional message formatting and grammar

## 📱 Frontend Pages

- `/` - Homepage
- `/listings` - Browse rentals
- `/ai-negotiator` - AI chat interface
- `/pricing` - Subscription plans
- `/login` - Authentication
- `/profile` - User dashboard

## 🔒 Security Features

- **Row Level Security**: Supabase RLS policies
- **Input Validation**: Server-side validation
- **Environment Variables**: Secure API key management
- **CORS Configuration**: Controlled cross-origin requests
- **Payment Security**: Stripe PCI compliance

## 🚀 Performance

- **Real-time Updates**: WebSocket subscriptions
- **Caching**: Market data caching
- **Auto-polling**: 3-second backup polling
- **Optimized Queries**: Efficient database operations

## 📊 Monitoring

- **Error Logging**: Comprehensive error tracking
- **Performance Metrics**: Response time monitoring
- **Success Rates**: Negotiation outcome tracking
- **User Analytics**: Platform usage statistics

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions:
- Create an issue on GitHub
- Contact: [your-email@example.com]

---

**Built with ❤️ using Advanced AI Negotiation Technology**