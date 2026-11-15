#!/usr/bin/env bash
# install.sh - the public first step of setting up a machine for a Claude Code agent.
# It installs the GitHub CLI, logs in to GitHub (it prints a code and a link), then clones the
# owner's private setup and runs it with the same options. Nothing private is in this file.
#
#   curl -fsSL https://raw.githubusercontent.com/tzarame/agent-plugins/main/claude/install/install.sh | bash
set -euo pipefail
PRIVATE=${AGENT_SETUP_REPO:-zog88/institor}; DEST="$HOME/.institor"
if ! command -v gh >/dev/null; then
  if command -v apt-get >/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq curl git ca-certificates >/dev/null
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg status=none
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq && sudo apt-get install -y -qq gh >/dev/null
  elif command -v pacman >/dev/null; then sudo pacman -Syu --needed --noconfirm git github-cli >/dev/null
  else echo "install.sh: no apt-get or pacman; install git and gh by hand" >&2; exit 1; fi
fi
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web < /dev/tty
gh auth setup-git
if [ -d "$DEST/.git" ]; then git -C "$DEST" pull --ff-only -q || true; else gh repo clone "$PRIVATE" "$DEST"; fi
exec bash "$DEST/claude/install/agent.sh" "$@"
