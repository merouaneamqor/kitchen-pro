#!/bin/bash

# Setup GitHub Environment Variables
# This script helps configure GitHub repository variables and secrets

set -e

echo "🚀 Setting up GitHub environment variables..."

# Check if GitHub CLI is installed and authenticated
if ! command -v gh >/dev/null 2>&1; then
    echo "❌ GitHub CLI not installed. Please install it first:"
    echo "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "echo 'deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
    echo "sudo apt update && sudo apt install gh"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub CLI. Please run: gh auth login"
    exit 1
fi

echo "🔑 Authenticated with GitHub CLI"

# Get current repository
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
if [ -z "$REPO" ]; then
    echo "❌ Could not determine repository. Make sure you're in a git repository."
    exit 1
fi

echo "📁 Repository: $REPO"

# Check if .ftp.env exists for values
if [ -f ".ftp.env" ]; then
    echo "📄 Found .ftp.env file, using values from it..."
    source .ftp.env
else
    echo "⚠️  No .ftp.env file found. Please enter values manually."
fi

# Set FTP_HOST
if [ -z "$FTP_HOST" ]; then
    read -p "Enter FTP Host (e.g., ftp.example.com): " FTP_HOST
fi
if [ -n "$FTP_HOST" ]; then
    echo "Setting FTP_HOST..."
    gh variable set FTP_HOST --body "$FTP_HOST"
fi

# Set FTP_USER
if [ -z "$FTP_USER" ]; then
    read -p "Enter FTP Username: " FTP_USER
fi
if [ -n "$FTP_USER" ]; then
    echo "Setting FTP_USER..."
    gh variable set FTP_USER --body "$FTP_USER"
fi

# Set FTP_PASS (as secret)
if [ -z "$FTP_PASS" ]; then
    read -s -p "Enter FTP Password: " FTP_PASS
    echo ""
fi
if [ -n "$FTP_PASS" ]; then
    echo "Setting FTP_PASS (as secret)..."
    echo "$FTP_PASS" | gh secret set FTP_PASS
fi

# Set DEPLOY_TOKEN (as secret)
if [ -z "$DEPLOY_TOKEN" ]; then
    read -s -p "Enter Deploy Token (leave empty to generate random): " DEPLOY_TOKEN
    echo ""
    if [ -z "$DEPLOY_TOKEN" ]; then
        DEPLOY_TOKEN=$(openssl rand -hex 16)
        echo "Generated random token: $DEPLOY_TOKEN"
    fi
fi
if [ -n "$DEPLOY_TOKEN" ]; then
    echo "Setting DEPLOY_TOKEN (as secret)..."
    echo "$DEPLOY_TOKEN" | gh secret set DEPLOY_TOKEN
fi

echo ""
echo "✅ GitHub environment variables configured!"
echo ""
echo "📋 Summary:"
echo "- FTP_HOST: Set as repository variable"
echo "- FTP_USER: Set as repository variable"
echo "- FTP_PASS: Set as repository secret"
echo "- DEPLOY_TOKEN: Set as repository secret"
echo ""
echo "🔒 Repository variables: https://github.com/$REPO/settings/variables/actions"
echo "🔐 Repository secrets: https://github.com/$REPO/settings/secrets/actions"
echo ""
echo "🧪 Test with: ./check-ftp-files.sh"
