#!/bin/bash

# Manual FTP Upload Test Script
# This script manually uploads files to test FTP connectivity and paths

set -e

echo "🧪 Manual FTP Upload Test..."

# Load FTP configuration
if [ -f ".ftp.env" ]; then
    source .ftp.env
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    echo "🔑 Using GitHub CLI to fetch credentials..."
    FTP_HOST=$(gh variable get FTP_HOST 2>/dev/null || echo "")
    FTP_USER=$(gh variable get FTP_USER 2>/dev/null || echo "")
    FTP_PASS=$(gh secret get FTP_PASS 2>/dev/null || echo "")
    DEPLOY_TOKEN=$(gh secret get DEPLOY_TOKEN 2>/dev/null || echo "")
elif [ -n "$FTP_HOST" ] && [ -n "$FTP_USER" ] && [ -n "$FTP_PASS" ]; then
    echo "✅ Using environment variables..."
else
    echo "❌ Error: FTP credentials not found."
    exit 1
fi

# Check if required variables are set
if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ]; then
    echo "❌ Error: FTP_HOST, FTP_USER, and FTP_PASS must be set"
    exit 1
fi

echo "🌐 Testing FTP upload to $FTP_HOST..."

# Create a test file to upload
echo "Creating test ZIP file..."
echo "Test file created at $(date)" > test.txt
zip -q test.zip test.txt

echo "📤 Testing upload to different paths..."

# Try different FTP paths
for FTP_PATH in "/htdocs" "/" "htdocs" "."; do
    echo "🔄 Testing path: $FTP_PATH"
    if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
    set ftp:passive-mode on;
    set ftp:ssl-allow yes;
    set ssl:verify-certificate no;
    set net:timeout 10;
    cd $FTP_PATH 2>/dev/null || echo 'Path $FTP_PATH not accessible';
    pwd;
    put test.zip;
    ls -la test.zip;
    bye" 2>&1 | grep -q "test.zip"; then
        echo "✅ Successfully uploaded to $FTP_PATH"
        WORKING_PATH="$FTP_PATH"

        # Also try to upload a simple PHP extractor
        cat > test-extract.php <<'PHP'
<?php
echo "Test extractor working!<br>";
echo "Current directory: " . __DIR__ . "<br>";
echo "Files: " . implode(', ', scandir(__DIR__)) . "<br>";
PHP

        lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
        set ftp:passive-mode on;
        set ftp:ssl-allow yes;
        set ssl:verify-certificate no;
        set net:timeout 10;
        cd $FTP_PATH;
        put test-extract.php;
        bye" 2>/dev/null

        break
    else
        echo "❌ Failed to upload to $FTP_PATH"
    fi
done

if [ -z "$WORKING_PATH" ]; then
    echo "❌ All paths failed, trying without SSL..."
    for FTP_PATH in "/htdocs" "/" "htdocs" "."; do
        echo "🔄 Testing path (no SSL): $FTP_PATH"
        if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
        set ftp:passive-mode off;
        set ftp:ssl-allow no;
        set net:timeout 10;
        cd $FTP_PATH 2>/dev/null || echo 'Path $FTP_PATH not accessible';
        pwd;
        put test.zip;
        ls -la test.zip;
        bye" 2>&1 | grep -q "test.zip"; then
            echo "✅ Successfully uploaded to $FTP_PATH (no SSL)"
            WORKING_PATH="$FTP_PATH"
            break
        else
            echo "❌ Failed to upload to $FTP_PATH (no SSL)"
        fi
    done
fi

# Cleanup
rm -f test.txt test.zip test-extract.php

if [ -n "$WORKING_PATH" ]; then
    echo ""
    echo "🎉 FTP test successful!"
    echo "✅ Working FTP path: $WORKING_PATH"
    echo "🧪 Test files uploaded. Check your website:"
    echo "   ZIP: https://$FTP_HOST/test.zip"
    echo "   PHP: https://$FTP_HOST/test-extract.php"
    echo ""
    echo "💡 Set this path in your GitHub workflow or use it for manual uploads"
else
    echo ""
    echo "❌ FTP upload test failed completely"
    echo "💡 Check your FTP credentials and network connectivity"
fi
