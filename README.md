# dotfiles

Minimal setup for coding in the terminal on a blank Mac.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/pthurlow/dotfiles/main/bootstrap.sh | bash
```

To read the script before running it:

```sh
curl -fsSL https://raw.githubusercontent.com/pthurlow/dotfiles/main/bootstrap.sh -o bootstrap.sh
less bootstrap.sh
bash bootstrap.sh
```

If the Xcode Command Line Tools installer pops up, finish it, then run the command again.

The script checks before changing anything, so it's safe to run on a Mac that's already set up:

- Tools, apps, Node and npm CLIs that already exist are skipped, including apps installed by hand.
- Git settings that are already set are kept.
- An existing SSH key, `~/.secrets` file or GitHub SSH config entry is left alone.
- If `~/.zshrc`, `~/.zprofile` or `~/.config/git/ignore` already exists and differs, it asks before replacing it (default no) and backs up the old copy to `~/.dotfiles-backup/<timestamp>/`.

## Options

Set these before `bash` to change the defaults:

| Variable | Default | Purpose |
|---|---|---|
| `ASSUME_YES` | `0` | `1` answers yes to every prompt, including replacing existing dotfiles (backups are still kept) |
| `GIT_NAME` | `pthurlow` | `git config user.name`, if not already set |
| `GIT_EMAIL` | asks | `git config user.email`, if not already set |
| `NODE_VERSION` | `lts/*` | Node version installed with nvm, if Node isn't already installed |

```sh
curl -fsSL https://raw.githubusercontent.com/pthurlow/dotfiles/main/bootstrap.sh | ASSUME_YES=1 bash
```

## What it sets up

- **Xcode Command Line Tools:** installs them if missing (asks first), or offers to update them.
- **Homebrew:** installs it if missing (asks first), or updates it and offers to upgrade packages.
- **Command-line tools:** git, git-lfs, gh, jq, wget, tmux, starship.
- **Apps:** Ghostty, iTerm2, VS Code, Docker Desktop, Claude, JetBrains Mono Nerd Font.
- **Node:** nvm with the current LTS, pnpm, plus the Claude Code, Codex and Gemini CLIs. Next.js is installed per project, not globally: start one with `pnpm create next-app my-app`.
- **Shell:** `~/.zshrc` and `~/.zprofile` with history, completion, git aliases and the starship prompt.
- **Git:** name, email, `main` as the default branch, and a global ignore file.
- **SSH:** an ed25519 key for GitHub, if you don't already have one.

## After installing

1. Open a new terminal, or run `exec zsh`.
2. Put API keys in `~/.secrets`. It is created empty, readable only by you, and never committed.
3. Log in to GitHub, and say yes when it offers to upload your SSH key:
   ```sh
   gh auth login --git-protocol ssh
   ```

Machine-specific shell settings go in `~/.zshrc.local`, which `~/.zshrc` loads if it exists.

## Git aliases

| Alias | Command |
|---|---|
| `g` | `git` |
| `gs` | `git status -sb` |
| `ga` / `gaa` | `git add` / `git add --all` |
| `gc` / `gcm` / `gca` | `git commit` / `git commit -m` / `git commit --amend` |
| `gco` / `gcb` / `gsw` | `git checkout` / `git checkout -b` / `git switch` |
| `gb` | `git branch` |
| `gd` / `gds` | `git diff` / `git diff --staged` |
| `gl` / `gla` | last 20 commits as a graph / all branches as a graph |
| `gp` / `gpl` | `git push` / `git pull` |
| `gf` | `git fetch --all --prune` |
| `gst` / `gstp` | `git stash` / `git stash pop` |
