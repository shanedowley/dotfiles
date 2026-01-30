# Shane’s Dotfiles

This repository contains my personal macOS dotfiles, managed using a **bare Git repository** and an intentionally **whitelisted sync workflow**.

It is designed to be:
- predictable
- boring
- low-maintenance
- hard to accidentally break

If something here feels strict, that’s by design.

---

## High-level design

### 1. Bare repo, real home directory

This repo is a **bare Git repository** living at:

```
~/.dotfiles
```

It tracks selected files **directly in `$HOME`** using:

```bash
git --git-dir=$HOME/.dotfiles --work-tree=$HOME
```

There is **no working copy folder** checked out elsewhere.

---

### 2. `dotgit` alias

All interaction with the bare repo happens via this alias:

```bash
alias dotgit='/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
```

Never run plain `git` in `$HOME`.

---

### 3. Whitelist-only tracking

Nothing is tracked automatically.

Only a **small, explicit set of paths** are ever staged, via the `dotsync` function in `~/.zshrc`.

If a file is not in that whitelist, it will **never** be committed.

This avoids:
- Neovim / CoC / cache pollution
- macOS protected directory hangs
- accidental secrets leaks
- “why did this get committed?” moments

---

## The only workflow you need

### Daily use (99% of the time)

```bash
dotsync
```

That’s it.

- If it commits → good  
- If it says “nothing to commit” → also good

You do **not** need to run `git status` day-to-day.

---

### Sanity checks (rare)

If something feels wrong:

```bash
dotgit diff
dotgit diff --cached
dotgit status
```

Avoid `-u` unless debugging ignores — it will be noisy by design.

---

## Tracked paths (intentional)

As of now, `dotsync` only stages:

- `~/.zshrc`
- `~/.gitconfig`
- `~/.gitignore`
- `~/.config/nvim`
- `~/.config/tmux`
- `~/.config/starship.toml`
- `~/.config/ghostty`
- `~/.config/aerospace`
- `~/.config/karabiner/karabiner.json`
- `~/.config/karabiner/assets/complex_modifications`
- `~/.config/sketchybar`
- `~/bin`
- `~/bootstrap.sh`

Anything else is intentionally ignored.

---

## Symlinks vs real files (important)

Rule of thumb:

- **Track the real file**, not the symlink  
- Symlinks are created only during bootstrap

Example:
- `~/.zshrc` → tracked as a real file  
- No parallel `dotfiles/zshrc` copy (this avoids confusion)

---

## bootstrap.sh

`bootstrap.sh` is a **minimal, safe starting point** for a new machine.

It:
- creates required directories
- sets up *intentional* symlinks
- sanity-checks Homebrew

It is not a full provisioning script — that is deliberate.

---

## Philosophy (read this if confused)

- Explicit > clever  
- Whitelists > ignores  
- Boring > magical  
- Reproducible > flexible  
- Muscle memory beats documentation  

If Future Shane is tempted to “just quickly track one more thing” — stop and think first.

---

## First command on a new machine

After cloning and setting up SSH:

```bash
./bootstrap.sh
```

Then open a new shell and continue as normal.

---

## Final note

If `dotsync` feels boring, quiet, and uneventful —  
that means it’s working exactly as intended.
