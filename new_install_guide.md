# Shane’s Dotfiles Bootstrap Guide  
## From Zero → Fully Working Environment

---

## Purpose

This document defines the exact, **repeatable process** to rebuild Shane’s full development environment from a **completely fresh macOS machine**.

No guesswork. No memory required.

---

## Pre-Requisites

You have:
- A fresh macOS system
- Internet connection
- Access to your GitHub account

---

## Step 1 — Open Terminal

On a new Mac:

- Press `Cmd + Space`
- Type **Terminal**
- Hit Enter

---

## Step 2 — Install Xcode Command Line Tools

Run:

```bash
xcode-select --install
```

- A popup will appear
- Click **Install**
- Wait for completion

---

## Step 3 — Set Up GitHub SSH Access

### Generate SSH key

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

Press Enter through all prompts.

---

### Copy SSH key

```bash
pbcopy < ~/.ssh/id_ed25519.pub
```

---

### Add to GitHub

1. Go to: https://github.com/settings/keys  
2. Click **New SSH Key**  
3. Paste key  
4. Save  

---

### Verify SSH works

```bash
ssh -T git@github.com
```

Expected output:

```
Hi shanedowley! You've successfully authenticated...
```

---

## Step 4 — Run Bootstrap Script

Run this **single command**:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/shanedowley/dotfiles/main/install.sh)"
```

---

## Step 5 — What the Script Does

The script will automatically:

- Ensure macOS environment
- Install Xcode CLT (if missing)
- Install Homebrew
- Install core tools:
  - git
  - neovim
  - tmux
  - ripgrep
  - fd
- Verify GitHub SSH access
- Clone dotfiles as a **bare repo** (`~/.dotfiles`)
- Check out dotfiles into `$HOME`
- Set up `dotgit` alias
- Configure Git to hide untracked files

---

## Step 6 — Reload Shell

When script completes:

```bash
exec zsh
```

---

## Step 7 — Verify Environment

Run:

```bash
dotgit status
```

Expected:

```
nothing to commit, working tree clean
```

---

Check tools:

```bash
nvim --version
tmux -V
```

---

## Step 8 — First Run of Neovim

```bash
nvim
```

- Plugins may install automatically
- Allow initial setup to complete

---

## System Architecture (Mental Model)

- **Bare repo**: `~/.dotfiles`
- **Working tree**: `$HOME`
- **Tracked files live directly in HOME**
- No `~/dotfiles` directory exists

---

## Key Commands

```bash
# Pull latest config
dotgit pull

# Check status
dotgit status

# View tracked files
dotgit ls-files
```

---

## Recovery / Safety

If conflicts occur during checkout:

- Files are moved to:

```
~/.dotfiles-checkout-backup
```

Nothing is lost.

---

## What This System Guarantees

- Reproducible environment
- Single source of truth (GitHub)
- No configuration drift
- Clean separation of:
  - system state
  - versioned config

---

## Future Improvements (Optional)

- Brewfile for extended packages
- dotdoctor validation script
- role-based installs (minimal / full)
- CI validation of bootstrap

---

## Final Principle

> If this process fails, the system is incomplete.  
> Fix the system — not the instructions.

---

**End of Document**
