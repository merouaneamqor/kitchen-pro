#!/bin/bash

# Check FTP Files using Environment Variables
# Simplified version that uses environment variables directly

set -e

echo "🔍 Checking FTP files using environment variables..."

# Check if required environment variables are set
if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ]; then
    echo "❌ Error: Environment variables not set."
    echo "Please set them first:"
    echo "export FTP_HOST='your-ftp-host.com'"
    echo "export FTP_USER='your-username'"
    echo "export FTP_PASS='your-password'"
    echo ""
    echo "Or run: source .ftp.env"
    exit 1
fi

echo "🌐 Connecting to $FTP_HOST..."

# List files in htdocs directory
lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
set ftp:passive-mode on;
set ftp:ssl-allow yes;
set ssl:verify-certificate no;
set net:timeout 10;
cd /htdocs;
echo '📁 Files in /htdocs:';
ls -la;
echo '';
echo '🔍 Looking for ZIP files:';
ls -la *.zip *.bin 2>/dev/null || echo 'No .zip or .bin files found';
echo '';
echo '📄 Looking for PHP files:';
ls -la *.php 2>/dev/null || echo 'No .php files found';
bye" 2>/dev/null || {
    echo "⚠️  SSL connection failed, trying without SSL..."
    lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
    set ftp:passive-mode on;
    set ftp:ssl-allow no;
    set net:timeout 10;
    cd /htdocs;
    echo '📁 Files in /htdocs:';
    ls -la;
    echo '';
    echo '🔍 Looking for ZIP files:';
    ls -la *.zip *.bin 2>/dev/null || echo 'No .zip or .bin files found';
    echo '';
    echo '📄 Looking for PHP files:';
    ls -la *.php 2>/dev/null || echo 'No .php files found';
    bye" 2>/dev/null || {
        echo "❌ FTP connection failed. Please check your credentials."
        exit 1
    }
}

echo ""
echo "💡 If you don't see deploy.bin or deploy-extract.php, the GitHub Actions upload failed."
