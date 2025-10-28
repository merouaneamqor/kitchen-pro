#!/bin/bash

# Check FTP Files Script
# Manually verify what files exist on the FTP server

set -e

echo "🔍 Checking files on FTP server..."

# Load FTP configuration
if [ -f ".ftp.env" ]; then
    source .ftp.env
else
    echo "❌ Error: .ftp.env file not found. Please create it with your FTP credentials."
    exit 1
fi

# Check if required variables are set
if [ -z "$FTP_HOST" ] || [ -z "$FTP_USER" ] || [ -z "$FTP_PASS" ]; then
    echo "❌ Error: FTP_HOST, FTP_USER, and FTP_PASS must be set in .ftp.env"
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
echo "💡 Try running the workflow again or check the GitHub Actions logs."
