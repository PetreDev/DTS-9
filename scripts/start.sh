#!/bin/bash
# Quick start script for Taskflow project
# This script automates the startup process when coming back fresh

set -e

echo "🚀 Starting Taskflow project..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Step 1: Start Docker services
echo "📦 Step 1/5: Starting Docker services..."
docker-compose up -d

echo "   Waiting for services to be healthy..."
sleep 10

# Check service health
echo "   Checking service status..."
docker-compose ps

echo ""
echo "⏳ Waiting 60 seconds for all services to fully start..."
sleep 60

# Step 2: Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo ""
    echo "📦 Step 2/5: Installing dependencies..."
    npm install
else
    echo ""
    echo "✓ Step 2/5: Dependencies already installed (skipping npm install)"
fi

# Step 3: Setup Kafka and Cassandra
echo ""
echo "🔧 Step 3/5: Setting up Kafka and Cassandra..."
if [ -f "scripts/setup-kafka.sh" ]; then
    npm run kafka:setup || echo "⚠️  Kafka setup had warnings, continuing..."
else
    echo "⚠️  setup-kafka.sh not found, skipping..."
fi

# Step 4: Push database schema
echo ""
echo "💾 Step 4/5: Pushing database schema..."
npm run db:push

# Step 5: Start dev server
echo ""
echo "🎉 Step 5/5: All set! Starting development server..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Project is ready!"
echo "   Open http://localhost:3000 in your browser"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

npm run dev
