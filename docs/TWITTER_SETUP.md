# Twitter/X Auto-Posting Setup Guide

This guide explains how to configure automatic Twitter/X posting for Flutter Skill releases.

## Overview

When you release a new version, GitHub Actions will automatically post a tweet announcing the release, including:
- Version number
- Installation commands (npm, Homebrew, Winget)
- Release notes link
- Relevant hashtags

## Prerequisites

You need a Twitter/X Developer account with API access.

## Step 1: Create Twitter Developer Account

1. **Go to Twitter Developer Portal**
   - Visit: https://developer.twitter.com/en/portal/dashboard
   - Sign in with your Twitter/X account

2. **Create a Project**
   - Click "Create Project"
   - Project name: `Flutter Skill Auto-Release`
   - Use case: `Making a bot`
   - Project description: `Automatic release announcements for Flutter Skill`

3. **Create an App**
   - App name: `flutter-skill-releases` (or any unique name)
   - Click "Complete"

## Step 2: Enable OAuth 2.0 and Get Bearer Token

### Method 1: Using OAuth 2.0 (Recommended)

1. **Generate Bearer Token**
   - In your app settings, go to "Keys and tokens" tab
   - Under "Authentication Tokens", click "Generate" for Bearer Token
   - **IMPORTANT:** Copy the Bearer Token immediately - you won't see it again!
   - Format: `AAAAAAAAAAAAAAAAAAAAAxxxxxxxxxxxxxxxxxxxxxxxx`

2. **Set App Permissions**
   - Go to "User authentication settings"
   - Click "Set up"
   - App permissions: Select "Read and write"
   - Type of App: "Web App, Automated App or Bot"
   - Callback URI: `https://github.com/ai-dashboad/flutter-skill` (required but not used)
   - Website URL: `https://github.com/ai-dashboad/flutter-skill`
   - Save

### Method 2: Using OAuth 1.0a (Alternative)

If OAuth 2.0 Bearer Token doesn't work, use API Keys:

1. **Generate API Keys**
   - In "Keys and tokens" tab:
   - API Key (Consumer Key): `xxxxxxxxxxxxxxxxxxxx`
   - API Key Secret (Consumer Secret): `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Access Token: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - Access Token Secret: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

2. **Note:** The GitHub Action uses Bearer Token by default. If using API Keys, you'll need to modify the workflow.

## Step 3: Add Twitter Credentials to GitHub Secrets

1. **Go to GitHub Repository Settings**
   - Visit: https://github.com/ai-dashboad/flutter-skill/settings/secrets/actions

2. **Add the Bearer Token**
   - Click "New repository secret"
   - Name: `TWITTER_BEARER_TOKEN`
   - Value: Paste your Bearer Token
   - Click "Add secret"

## Step 4: Test the Setup

### Option 1: Test with Next Release

Simply release a new version:
```bash
./scripts/release.sh 0.5.4 "Your release description"
```

The GitHub Action will automatically post to Twitter.

### Option 2: Manual Test (Advanced)

Trigger the workflow manually to test:

1. Go to: https://github.com/ai-dashboad/flutter-skill/actions/workflows/release.yml
2. Click "Run workflow"
3. Select branch: `main`
4. Run workflow

## Step 5: Verify

After a release, check:

1. **GitHub Actions Log**
   - https://github.com/ai-dashboad/flutter-skill/actions
   - Look for "Post to X (Twitter)" step
   - Check for success ✅ or errors ❌

2. **Your Twitter/X Profile**
   - Visit your Twitter profile
   - Verify the release announcement was posted

## Troubleshooting

### Error: "Unauthorized" (401)

**Cause:** Invalid or expired Bearer Token

**Fix:**
1. Regenerate Bearer Token in Twitter Developer Portal
2. Update `TWITTER_BEARER_TOKEN` secret in GitHub

### Error: "Forbidden" (403)

**Cause:** App permissions not set to "Read and write"

**Fix:**
1. Go to Twitter Developer Portal → Your App → Settings
2. Set App permissions to "Read and write"
3. Regenerate tokens after changing permissions

### Error: "Too Many Requests" (429)

**Cause:** Rate limit exceeded

**Fix:**
- Wait for rate limit to reset (15 minutes for most endpoints)
- Twitter has strict rate limits for posting tweets

### Tweet Not Posted but No Error

**Cause:** Duplicate tweet detection

**Fix:**
- Twitter blocks duplicate tweets within a short time window
- Each release should have unique content (version number changes)

## Customizing Tweet Content

To customize the tweet content, edit `.github/workflows/release.yml`:

```yaml
# In post-to-twitter job, find the "Extract changelog entry" step
cat > tweet.txt << 'EOF'
🚀 Your custom message here
EOF
```

**Important:**
- Keep tweets under 280 characters
- Include version variable: `v$VERSION`
- Use hashtags for discoverability

## Security Best Practices

1. **Never commit tokens to git**
   - Always use GitHub Secrets
   - Never log tokens in Actions output

2. **Use minimum required permissions**
   - Bearer Token only needs "Read and write" tweets permission
   - Don't grant DM or additional permissions unless needed

3. **Rotate tokens periodically**
   - Regenerate Bearer Token every 6-12 months
   - Update GitHub Secret after rotation

## Alternative: Using Twitter Action (Optional)

If you prefer using a GitHub Action instead of curl, you can use:

```yaml
- name: Post to Twitter
  uses: nearform-actions/github-action-notify-twitter@v1
  with:
    message: ${{ steps.changelog.outputs.tweet }}
    twitter-app-key: ${{ secrets.TWITTER_API_KEY }}
    twitter-app-secret: ${{ secrets.TWITTER_API_SECRET }}
    twitter-access-token: ${{ secrets.TWITTER_ACCESS_TOKEN }}
    twitter-access-token-secret: ${{ secrets.TWITTER_ACCESS_SECRET }}
```

This requires OAuth 1.0a credentials (4 separate secrets).

## Resources

- [Twitter API Documentation](https://developer.twitter.com/en/docs/twitter-api)
- [Twitter API v2 - Create Tweet](https://developer.twitter.com/en/docs/twitter-api/tweets/manage-tweets/api-reference/post-tweets)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

---

**Questions or Issues?**

Open an issue: https://github.com/ai-dashboad/flutter-skill/issues
