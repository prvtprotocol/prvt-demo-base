# Git Push Instructions

## Option 1: Fork Repository (Recommended if you don't have write access)

1. Go to https://github.com/prvtprotocol/prvt-demo-base
2. Click "Fork" button (top right)
3. Fork to your account
4. Update remote to your fork:
```bash
git remote set-url origin https://github.com/YOUR_USERNAME/prvt-demo-base.git
git push -u origin main
```

## Option 2: Use Personal Access Token (If you have write access)

1. Generate PAT: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Create token with `repo` scope
3. Update remote to use PAT:
```bash
git remote set-url origin https://YOUR_TOKEN@github.com/prvtprotocol/prvt-demo-base.git
git push -u origin main
```

## Option 3: Use SSH (If SSH keys are configured)

1. Update remote:
```bash
git remote set-url origin git@github.com:prvtprotocol/prvt-demo-base.git
git push -u origin main
```

## Option 4: Request Collaborator Access

Contact repository owner to add you as a collaborator with write access.

