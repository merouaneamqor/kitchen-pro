#!/bin/bash

# Manual FTP Upload Script
# Directly upload files to FTP server for testing

set -e

echo "📤 Manual FTP Upload..."

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

# Check if deploy.bin exists
if [ ! -f "deploy.bin" ]; then
    echo "❌ deploy.bin not found. Building it first..."
    echo "Test content" > test.txt
    zip -q deploy.bin test.txt
    echo "✅ Created test deploy.bin"
fi

echo "🌐 Uploading to $FTP_HOST..."

# Try to upload to /htdocs first (most common for InfinityFree)
echo "🔄 Uploading to /htdocs..."
if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
set ftp:passive-mode on;
set ftp:ssl-allow yes;
set ssl:verify-certificate no;
set net:timeout 20;
cd /htdocs;
put deploy.bin;
ls -la deploy.bin;
bye" 2>&1; then
    echo "✅ Successfully uploaded to /htdocs"
    UPLOAD_PATH="/htdocs"
else
    echo "❌ Failed to upload to /htdocs, trying without SSL..."
    if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
    set ftp:passive-mode off;
    set ftp:ssl-allow no;
    set net:timeout 20;
    cd /htdocs;
    put deploy.bin;
    ls -la deploy.bin;
    bye" 2>&1; then
        echo "✅ Successfully uploaded to /htdocs (no SSL)"
        UPLOAD_PATH="/htdocs"
    else
        echo "❌ Upload failed. Trying root directory..."
        if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
        set ftp:passive-mode off;
        set ftp:ssl-allow no;
        set net:timeout 20;
        put deploy.bin;
        ls -la deploy.bin;
        bye" 2>&1; then
            echo "✅ Successfully uploaded to root"
            UPLOAD_PATH="/"
        else
            echo "❌ All upload attempts failed!"
            exit 1
        fi
    fi
fi

# Create and upload extractor script
echo "📝 Creating extractor script..."
cat > deploy-extract.php <<'PHP'
<?php
$expected = 'REPLACE_TOKEN';
if (!isset($_GET['token']) || $_GET['token'] !== $expected) { http_response_code(403); exit('Forbidden'); }

echo "🔍 Debug Info:<br>";
echo "Current directory: " . __DIR__ . "<br>";
echo "Files in directory: " . implode(', ', scandir(__DIR__)) . "<br>";

if (!class_exists('ZipArchive')) { http_response_code(500); exit('ZipArchive not available'); }

$possiblePaths = [
    __DIR__ . '/deploy.bin',
    __DIR__ . '/krayin-shared.zip',
    dirname(__DIR__) . '/deploy.bin',
    dirname(__DIR__) . '/krayin-shared.zip'
];

$zipPath = null;
foreach ($possiblePaths as $path) {
    echo "Looking for: $path<br>";
    if (file_exists($path)) {
        $zipPath = $path;
        echo "✅ Found ZIP file: $path<br>";
        break;
    }
}

if (!$zipPath) {
    echo "<br>❌ ZIP file not found!<br>";
    exit('ZIP not found');
}

echo "File size: " . filesize($zipPath) . " bytes<br>";

$zip = new ZipArchive();
$openResult = $zip->open($zipPath);
if ($openResult !== true) {
    exit('Cannot open zip (error: ' . $openResult . ')');
}

echo "ZIP contains " . $zip->numFiles . " files<br>";
echo "Extracting...<br>";

if (!$zip->extractTo(__DIR__)) {
    exit('Extract failed');
}

$zip->close();
@unlink($zipPath);
@unlink(__FILE__);
echo '<br>✅ OK - Extraction completed successfully!';
PHP

# Replace token
if [ -n "$DEPLOY_TOKEN" ]; then
    sed -i "s/REPLACE_TOKEN/$DEPLOY_TOKEN/g" deploy-extract.php
else
    # Generate a random token
    DEPLOY_TOKEN=$(openssl rand -hex 8 2>/dev/null || echo "test123")
    sed -i "s/REPLACE_TOKEN/$DEPLOY_TOKEN/g" deploy-extract.php
fi

# Upload extractor script
echo "📤 Uploading extractor script..."
lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "
set ftp:passive-mode off;
set ftp:ssl-allow no;
set net:timeout 20;
cd $UPLOAD_PATH;
put deploy-extract.php;
ls -la deploy-extract.php;
bye" 2>/dev/null

echo ""
echo "🎉 Manual upload completed!"
echo "📁 Files uploaded to: $UPLOAD_PATH"
echo "🔗 Extractor URL: https://$FTP_HOST/deploy-extract.php?token=$DEPLOY_TOKEN"
echo ""
echo "🧹 Cleaning up local files..."
rm -f deploy.bin test.txt deploy-extract.php
