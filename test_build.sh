#!/bin/bash

# BrowserStack Flutter App Build Script
# Optimized for white screen issue resolution

echo "🚀 Starting BrowserStack-optimized build..."

# Load environment variables
if [ -f "env.json" ]; then
    echo "📋 Loading environment variables from env.json..."
    export SUPABASE_URL=$(cat env.json | jq -r '.SUPABASE_URL')
    export SUPABASE_ANON_KEY=$(cat env.json | jq -r '.SUPABASE_ANON_KEY')
else
    echo "⚠️ env.json not found, using default values"
    export SUPABASE_URL="https://rsskivonmfqrzxbmxrkl.supabase.co"
    export SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJzc2tpdm9ubWZxcnp4Ym14cmtsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2NTUxMTgsImV4cCI6MjA2NzIzMTExOH0.uYjeiqI7eNGZqnip4p-20AL6NT9YCos15gWY-lP82As"
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
flutter pub get

# Build for Android with BrowserStack optimizations
echo "� Building Android APK for BrowserStack..."

flutter build apk \
    --release \
    --target-platform android-arm64 \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=FLUTTER_WEB_USE_SKIA=true \
    --dart-define=FLUTTER_WEB_USE_SKIA_FOR_TEXT=true \
    --dart-define=FLUTTER_WEB_USE_SKIA_FOR_IMAGES=true

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo "📦 APK location: build/app/outputs/flutter-apk/app-release.apk"
    
    # Optional: Install on connected device
    if command -v adb &> /dev/null; then
        echo "📱 Installing on connected device..."
        adb install build/app/outputs/flutter-apk/app-release.apk
    fi
else
    echo "❌ Build failed!"
    exit 1
fi

echo "🎉 BrowserStack build script completed!"