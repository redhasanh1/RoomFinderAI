#!/bin/bash
set -e

echo "🚀 Starting RoomFinderAI deployment..."

# Install root dependencies
echo "📦 Installing root dependencies..."
npm install --production

# Install backend dependencies
echo "📦 Installing backend dependencies..."
cd backend && npm install --production && cd ..

# Start the server
echo "🌟 Starting server..."
cd backend && node server.js