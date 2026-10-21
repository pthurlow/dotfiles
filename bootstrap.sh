#!/usr/bin/env bash
#
# bootstrap.sh — minimal setup for coding in the terminal on a blank Mac.
#
#   curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/main/bootstrap.sh | bash
#   # or
#   bash bootstrap.sh
#
# Safe to re-run: every step checks before installing, and any dotfile it
# replaces is first copied to ~/.dotfiles-backup/<timestamp>/.
#
# Secrets (API keys, tokens) never live here. They go in ~/.secrets, which
# this script creates empty with mode 600 and ~/.zshrc sources if present.
#
# Override defaults with env vars, e.g.:
#   GIT_NAME="Jane" GIT_EMAIL="jane@example.com" NODE_VERSION=22 bash bootstrap.sh
#   ASSUME_YES=1 bash bootstrap.sh   # answer yes to every prompt

set -euo pipefail

GIT_NAME="${GIT_NAME:-pthurlow}"
GIT_EMAIL="${GIT_EMAIL:-}"
NODE_VERSION="${NODE_VERSION:-lts/*}"
ASSUME_YES="${ASSUME_YES:-0}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
info() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Read from the terminal even when the script itself arrives on stdin (curl | bash).
ask() {
  local prompt="$1" reply=""
  if [ -r /dev/tty ]; then read -r -p "$prompt" reply </dev/tty || true; fi
  printf '%s' "$reply"
}

# confirm "Question?" [default y|n] — returns 0 for yes.
confirm() {
  local default="${2:-y}" hint reply
  [ "$ASSUME_YES" = 1 ] && return 0
  [ "$default" = y ] && hint="[Y/n]" || hint="[y/N]"
  reply="$(ask "$1 $hint ")"
  reply="${reply:-$default}"
  [[ "$reply" =~ ^[Yy] ]]
}

# Write stdin to a file, backing up whatever was there if it differs.
install_file() {
  local dest="$1" tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm "$tmp"; return
  fi
  if [ -e "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -p "$dest" "$BACKUP_DIR/$(basename "$dest")"
    echo "  backed up $dest -> $BACKUP_DIR/"
  fi
  mkdir -p "$(dirname "$dest")"
  mv "$tmp" "$dest"
  echo "  wrote $dest"
}

[ "$(uname -s)" = "Darwin" ] || { echo "This script targets macOS." >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Xcode Command Line Tools (git, clang, make)
# ---------------------------------------------------------------------------
info "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
  echo "  found at $(xcode-select -p)"
  if confirm "Check for Command Line Tools updates? (can be slow)" n; then
    clt_update="$(softwareupdate -l 2>/dev/null | sed -n 's/^\* Label: \(Command Line Tools.*\)$/\1/p' | tail -n1)"
    if [ -n "$clt_update" ]; then
      sudo softwareupdate -i "$clt_update" --verbose
    else
      echo "  up to date"
    fi
  fi
elif confirm "Command Line Tools not found. Install them?"; then
  xcode-select --install || true
  echo "Finish the installer dialog, then re-run this script."
  exit 0
else
  warn "skipping Command Line Tools; git and compilers may be missing"
fi

# ---------------------------------------------------------------------------
# 2. Homebrew + packages
# ---------------------------------------------------------------------------
info "Homebrew"
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$b" ] && eval "$("$b" shellenv)" && break
done

if have brew; then
  echo "  found at $(command -v brew)"
  brew update
  if confirm "Upgrade installed Homebrew packages?" n; then brew upgrade; fi
elif confirm "Homebrew not found. Install it?"; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
fi

if have brew; then
  info "Homebrew packages"
  brew bundle --file=- <<'BREWFILE' || warn "some brew packages failed; re-run or install them by hand"
# --- cli ----------------------------------------------------------------------
brew "git"
brew "git-lfs"
brew "gh"
brew "jq"
brew "wget"
brew "tmux"
brew "starship"          # prompt

# --- apps ---------------------------------------------------------------------
cask "ghostty"
cask "iterm2"
cask "visual-studio-code"
cask "docker-desktop"
cask "claude"
cask "font-jetbrains-mono-nerd-font"   # glyphs for the starship prompt
BREWFILE
  git lfs install --skip-repo >/dev/null
else
  warn "skipping Homebrew packages (no Homebrew)"
fi

# ---------------------------------------------------------------------------
# 3. Node (nvm) + global CLIs
# ---------------------------------------------------------------------------
info "Node (nvm)"
export NVM_DIR="$HOME/.nvm"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh)"
fi
set +u  # nvm.sh is not nounset-safe
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION" >/dev/null
set -u

info "Global npm packages"
npm install -g \
  @anthropic-ai/claude-code \
  @openai/codex \
  @google/gemini-cli \
  || warn "some npm globals failed"

# ---------------------------------------------------------------------------
# 4. Dotfiles
# ---------------------------------------------------------------------------
info "Shell dotfiles"

install_file "$HOME/.zprofile" <<'EOF'
# Login shells: put Homebrew on PATH.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
EOF

install_file "$HOME/.zshrc" <<'EOF'
# ~/.zshrc — interactive shell config. Managed by dotfiles/bootstrap.sh.
# Machine-specific tweaks go in ~/.zshrc.local; secrets go in ~/.secrets.

# --- history ---------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# --- completion ------------------------------------------------------------
autoload -Uz compinit && compinit -i
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # case-insensitive

# --- PATH ------------------------------------------------------------------
typeset -U path   # de-duplicate
path=("$HOME/.local/bin" $path)
export PATH

# --- node ------------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# --- aliases ---------------------------------------------------------------
alias ll='ls -lAhG'

# git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gsw='git switch'
alias gb='git branch'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all'
alias gp='git push'
alias gpl='git pull'
alias gf='git fetch --all --prune'
alias gst='git stash'
alias gstp='git stash pop'

# --- prompt ----------------------------------------------------------------
command -v starship >/dev/null && eval "$(starship init zsh)"

# --- local overrides (not in git) ------------------------------------------
[ -f "$HOME/.secrets" ] && . "$HOME/.secrets"
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
EOF

if [ ! -f "$HOME/.secrets" ]; then
  install_file "$HOME/.secrets" <<'EOF'
# ~/.secrets — API keys and tokens. NEVER commit this file.
# export ANTHROPIC_API_KEY=""
# export OPENAI_API_KEY=""
# export GEMINI_API_KEY=""
EOF
fi
chmod 600 "$HOME/.secrets"

info "Git"
if [ -z "$GIT_EMAIL" ]; then
  GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
fi
if [ -z "$GIT_EMAIL" ]; then
  GIT_EMAIL="$(ask 'Git email (blank to skip): ')"
fi

install_file "$HOME/.config/git/ignore" <<'EOF'
.DS_Store
**/.claude/settings.local.json
.env
.env.local
EOF

git config --global user.name "$GIT_NAME"
[ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global push.autoSetupRemote true
git config --global core.excludesfile "$HOME/.config/git/ignore"

# ---------------------------------------------------------------------------
# 5. SSH key for GitHub
# ---------------------------------------------------------------------------
info "SSH"
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -C "${GIT_EMAIL:-$USER@$(hostname -s)}" -f "$HOME/.ssh/id_ed25519" -N ""
  NEW_SSH_KEY=1
fi
if ! grep -q '^Host github.com' "$HOME/.ssh/config" 2>/dev/null; then
  cat >>"$HOME/.ssh/config" <<'EOF'

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
  chmod 600 "$HOME/.ssh/config"
fi
ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" 2>/dev/null || true

# ---------------------------------------------------------------------------
# done
# ---------------------------------------------------------------------------
info "Done"
cat <<EOF

Next steps:
  1. Open a new terminal (or: exec zsh).
  2. Put your API keys in ~/.secrets.
  3. Log in to GitHub:  gh auth login --git-protocol ssh
EOF
[ "${NEW_SSH_KEY:-0}" = 1 ] && echo "     (it will offer to upload the new key ~/.ssh/id_ed25519.pub)"
[ -d "$BACKUP_DIR" ] && echo "  Replaced files were backed up to $BACKUP_DIR"
exit 0
