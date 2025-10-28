#!/bin/bash

# Test Workflow FTP Upload Script
# This replicates the exact FTP upload logic from the GitHub Actions workflow

set -e

echo "🧪 Testing Workflow FTP Upload Logic..."

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

# Create a test deploy.bin file (simulate the workflow)
echo "📦 Creating test deploy.bin file..."
echo "Test deployment file - $(date)" > test-content.txt
zip -q deploy.bin test-content.txt

echo "🚀 Starting FTP upload test to $FTP_HOST..."
echo "📁 Current directory: $(pwd)"
echo "📄 File to upload: deploy.bin"
echo "📊 File size: $(ls -lh deploy.bin)"
echo "🔑 FTP User: $FTP_USER"
echo "🌐 FTP Host: $FTP_HOST"

# First, test basic FTP connection
echo ""
echo "🔗 Testing basic FTP connection..."
if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
set ftp:passive-mode on;
set ftp:ssl-allow yes;
set ssl:verify-certificate no;
set net:timeout 10;
pwd;
ls;
bye" 2>&1; then
  echo "✅ Basic FTP connection successful"
  USE_SSL=true
else
  echo "❌ Basic FTP connection failed, trying without SSL..."
  if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
  set ftp:passive-mode off;
  set ftp:ssl-allow no;
  set net:timeout 10;
  pwd;
  ls;
  bye" 2>&1; then
    echo "✅ Basic FTP connection successful (no SSL)"
    USE_SSL=false
  else
    echo "❌ FTP connection completely failed!"
    echo "💡 Check your FTP credentials and network"
    exit 1
  fi
fi

# Try different FTP paths for InfinityFree
echo ""
UPLOAD_PATH=""
for FTP_PATH in "/htdocs" "/" "htdocs" "."; do
  echo "🔄 Trying FTP path: $FTP_PATH"

  if [ "$USE_SSL" = "true" ]; then
    # Try with SSL first
    echo "  📡 Testing with SSL..."
    OUTPUT=$(lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
    set ftp:passive-mode on;
    set ftp:ssl-allow yes;
    set ssl:verify-certificate no;
    set net:max-retries 1;
    set net:timeout 15;
    set cmd:fail-exit yes;
    cd $FTP_PATH 2>/dev/null && echo 'Changed to $FTP_PATH' || echo 'Cannot cd to $FTP_PATH';
    pwd;
    put -c deploy.bin 2>/dev/null && echo 'Upload completed' || echo 'Upload failed';
    ls -la deploy.bin 2>/dev/null && echo 'File verified' || echo 'File not found after upload';
    bye" 2>&1)

    echo "  📝 Output: $OUTPUT"
    if echo "$OUTPUT" | grep -q "File verified"; then
      echo "✅ Successfully uploaded to $FTP_PATH (SSL)"
      UPLOAD_PATH="$FTP_PATH"
      break
    fi
  fi

  # Try without SSL
  echo "  📡 Testing without SSL..."
  OUTPUT=$(lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
  set ftp:passive-mode off;
  set ftp:ssl-allow no;
  set net:max-retries 1;
  set net:timeout 15;
  set cmd:fail-exit yes;
  cd $FTP_PATH 2>/dev/null && echo 'Changed to $FTP_PATH' || echo 'Cannot cd to $FTP_PATH';
  pwd;
  put -c deploy.bin 2>/dev/null && echo 'Upload completed' || echo 'Upload failed';
  ls -la deploy.bin 2>/dev/null && echo 'File verified' || echo 'File not found after upload';
  bye" 2>&1)

  echo "  📝 Output: $OUTPUT"
  if echo "$OUTPUT" | grep -q "File verified"; then
    echo "✅ Successfully uploaded to $FTP_PATH (no SSL)"
    UPLOAD_PATH="$FTP_PATH"
    break
  else
    echo "❌ Failed to upload to $FTP_PATH"
  fi
done

# Cleanup test files
rm -f test-content.txt deploy.bin

if [ -n "$UPLOAD_PATH" ]; then
  echo ""
  echo "🎉 Upload test successful!"
  echo "✅ Working FTP path: $UPLOAD_PATH"
  echo "✅ SSL: $USE_SSL"
  echo ""
  echo "💡 The workflow should work with these settings"
  echo "💡 Check your GitHub Actions logs for similar output"
else
  echo ""
  echo "❌ FTP upload test failed completely!"
  echo "💡 Possible issues:"
  echo "   - FTP credentials incorrect"
  echo "   - FTP server blocking uploads"
  echo "   - Insufficient permissions"
  echo "   - Network/firewall issues"
  echo ""
  echo "🔧 Try running with more verbose output:"
  echo "   lftp -u '$FTP_USER','***' '$FTP_HOST' -e 'ls; bye'"
fi
