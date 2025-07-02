#!/bin/bash
set -e

echo "🚀 Starting RoomFinderAI deployment..."

# Install root dependencies
echo "📦 Installing root dependencies..."
npm install --production

# Install backend dependencies
echo "📦 Installing backend dependencies..."
npm install --prefix backend --production

# Start the server
echo "🌟 Starting server..."
node backend/server.js