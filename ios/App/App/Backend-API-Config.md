# Backend API Configuration for iOS

This document outlines the backend changes needed to support the iOS app properly.

## 1. CORS Configuration

Add these headers to your backend responses:

```javascript
// Express.js middleware example
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS, PATCH');
  res.header('Access-Control-Allow-Headers', 
    'Origin, X-Requested-With, Content-Type, Accept, Authorization, ' +
    'X-Platform, X-App-Version, X-Device-Id, X-OS-Version, X-Capacitor-Platform, ' +
    'X-Request-Id, Cache-Control, Pragma, Sec-Fetch-Site, Sec-Fetch-Mode, Sec-Fetch-Dest'
  );
  res.header('Access-Control-Allow-Credentials', 'true');
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});
```

## 2. API Key Endpoint

Create a secure endpoint to provide API keys to authenticated users:

```javascript
// GET /api/config/keys
app.get('/api/config/keys', authenticateToken, (req, res) => {
  // Only return keys for authenticated users
  const keys = {
    openai_key: process.env.OPENAI_API_KEY,
    google_api_key: process.env.GOOGLE_API_KEY,
    stripe_publishable_key: process.env.STRIPE_PUBLISHABLE_KEY,
    sentry_dsn: process.env.SENTRY_DSN
  };
  
  // Filter out undefined keys
  const filteredKeys = Object.fromEntries(
    Object.entries(keys).filter(([_, value]) => value !== undefined)
  );
  
  res.json(filteredKeys);
});
```

## 3. Health Check Endpoint

```javascript
// GET /health
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || '1.0.0',
    platform: req.headers['x-platform'] || 'unknown'
  });
});
```

## 4. Environment Configuration

```javascript
// GET /api/config
app.get('/api/config', (req, res) => {
  res.json({
    SUPABASE_URL: process.env.SUPABASE_URL,
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY,
    GOOGLE_API_KEY: process.env.GOOGLE_MAPS_API_KEY // Public key only
  });
});
```

## 5. Request Logging Middleware

Log requests from mobile clients for debugging:

```javascript
app.use((req, res, next) => {
  if (req.headers['x-platform'] === 'iOS') {
    console.log(`iOS Request: ${req.method} ${req.path}`, {
      userAgent: req.headers['user-agent'],
      appVersion: req.headers['x-app-version'],
      deviceId: req.headers['x-device-id'],
      osVersion: req.headers['x-os-version']
    });
  }
  next();
});
```

## 6. Error Handling

Return consistent error format:

```javascript
app.use((err, req, res, next) => {
  const error = {
    success: false,
    message: err.message,
    code: err.code || 'INTERNAL_ERROR',
    timestamp: new Date().toISOString()
  };
  
  // Add request ID for tracking
  if (req.headers['x-request-id']) {
    error.requestId = req.headers['x-request-id'];
  }
  
  res.status(err.status || 500).json(error);
});
```

## 7. Rate Limiting

Implement rate limiting for mobile clients:

```javascript
const rateLimit = require('express-rate-limit');

const mobileRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.',
    code: 'RATE_LIMIT_EXCEEDED'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api', mobileRateLimit);
```

## 8. Authentication Middleware

```javascript
const jwt = require('jsonwebtoken');

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Access token required',
      code: 'TOKEN_REQUIRED'
    });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({
        success: false,
        message: 'Invalid or expired token',
        code: 'TOKEN_INVALID'
      });
    }
    
    req.user = user;
    next();
  });
}
```

## 9. File Upload Configuration

For handling image uploads from mobile:

```javascript
const multer = require('multer');
const upload = multer({
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files allowed'), false);
    }
  }
});

app.post('/api/upload', authenticateToken, upload.single('file'), (req, res) => {
  // Handle file upload
  res.json({
    success: true,
    fileUrl: `/uploads/${req.file.filename}`,
    filename: req.file.filename
  });
});
```

## 10. WebSocket Configuration (if using)

```javascript
const io = require('socket.io')(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
    credentials: true
  }
});

io.on('connection', (socket) => {
  const platform = socket.handshake.headers['x-platform'];
  console.log(`New connection from ${platform || 'web'}`);
  
  // Handle mobile-specific events
  if (platform === 'iOS') {
    socket.join('mobile-users');
  }
});
```