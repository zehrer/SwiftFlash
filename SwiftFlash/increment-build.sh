#!/bin/bash

# Manual build number increment script
# Usage: ./increment-build.sh

PROJECT_FILE="SwiftFlash.xcodeproj/project.pbxproj"

# Check if the project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

# Get current build number
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | head -1 | sed 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/')

if [ -z "$CURRENT_BUILD" ]; then
    echo "❌ Could not find CURRENT_PROJECT_VERSION in project file"
    exit 1
fi

# Increment build number
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "🔧 Incrementing build number: $CURRENT_BUILD → $NEW_BUILD"

# Update build number in project file (both Debug and Release configurations)
sed -i '' "s/CURRENT_PROJECT_VERSION = $CURRENT_BUILD;/CURRENT_PROJECT_VERSION = $NEW_BUILD;/g" "$PROJECT_FILE"

echo "✅ Build number updated to $NEW_BUILD"
echo "📝 Don't forget to commit the changes: git add $PROJECT_FILE && git commit -m 'Bump build number to $NEW_BUILD'" 