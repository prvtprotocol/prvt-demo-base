# Git Authentication for prvtprotocol Repository

## Quick Setup - Use Personal Access Token

### Step 1: Create Personal Access Token
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token" → "Generate new token (classic)"
3. Name: "prvt-demo-base-push"
4. Select scopes: **repo** (full control of private repositories)
5. Click "Generate token"
6. **COPY THE TOKEN IMMEDIATELY** (you won't see it again!)

### Step 2: Push with Token
```bash
# Option A: Use token in URL (one-time)
git push https://YOUR_TOKEN@github.com/prvtprotocol/prvt-demo-base.git main

# Option B: Configure credential helper (recommended)
git config --global credential.helper store
git push -u origin main
# When prompted:
# Username: prvtprotocol (or your GitHub username)
# Password: [paste your token]
```

### Step 3: Verify
```bash
git remote -v
git push -u origin main
```

## Alternative: SSH Authentication
If you have SSH keys set up:
```bash
git remote set-url origin git@github.com:prvtprotocol/prvt-demo-base.git
git push -u origin main
```

