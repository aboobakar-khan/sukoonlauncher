#!/bin/bash

echo "🚀 Building Sukoon Launcher v1.1.2 (Build 26)"
echo "================================================"

cd "/Users/aboobakar/Study Content/minimalist_app-main"

echo "📦 Building Android App Bundle..."
flutter build appbundle --release

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    
    AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
    DEST_PATH="$HOME/Downloads/sukoon-launcher-v1.1.2-b26.aab"
    
    if [ -f "$AAB_PATH" ]; then
        cp "$AAB_PATH" "$DEST_PATH"
        echo ""
        echo "✅ AAB copied to Downloads!"
        echo "📍 Location: $DEST_PATH"
        echo ""
        echo "📊 File Info:"
        ls -lh "$DEST_PATH"
        echo ""
        echo "✨ Done! You can now upload this AAB to Google Play Console."
    else
        echo "❌ Error: AAB file not found at $AAB_PATH"
        exit 1
    fi
else
    echo "❌ Build failed!"
    exit 1
fi
