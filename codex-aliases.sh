# ============================
# Codex CLI Helper Aliases
# ============================

# General-purpose Q&A (chat mode)
alias ask='codex'

# Interactive Codex REPL session
alias chat='codex'

# Generate new code from a prompt
alias codegen='codex'

# Refactor / transform a file with Codex
refactor() {
  if [ $# -lt 2 ]; then
    echo "Usage: refactor <file> \"<instruction>\""
    return 1
  fi
  local file="$1"
  local instruction="$2"
  codex exec "Refactor: $instruction" < "$file"
}

# Debug a file with Codex
debug() {
  if [ $# -lt 2 ]; then
    echo "Usage: debug <file> \"<instruction>\""
    return 1
  fi
  local file="$1"
  local instruction="$2"
  codex exec "Debug: $instruction" < "$file"
}

# Diff mode: generate patch and open in Neovim
codex-diff() {
  if [ $# -lt 2 ]; then
    echo "Usage: codex-diff <file> \"<instruction>\""
    return 1
  fi
  local file="$1"
  local instruction="$2"
  codex exec "Diff: $instruction" < "$file" > /tmp/codex_patch.diff
  echo "Patch saved to /tmp/codex_patch.diff"
  nvim /tmp/codex_patch.diff
}

