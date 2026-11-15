#!/usr/bin/env bash
# install.sh - the public first step of setting up a machine for a Claude Code agent.
# It installs the GitHub CLI in ~/.local/bin (no sudo), logs in to GitHub (it prints a code and a link), then clones the
# owner's private setup and runs it with the same options. Nothing private is in this file.
#
#   curl -fsSL https://raw.githubusercontent.com/tzarame/agent-plugins/main/claude/install/install.sh | bash
set -euo pipefail
PRIVATE=${AGENT_SETUP_REPO:-zog88/institor}; DEST="$HOME/.institor"
export PATH="$HOME/.local/bin:$PATH"
if ! command -v gh >/dev/null; then   # the GitHub CLI as a user program, no sudo
  arch=$(uname -m); case $arch in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; esac
  v=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)
  t=$(mktemp -d); curl -fsSL "https://github.com/cli/cli/releases/download/v$v/gh_${v}_linux_$arch.tar.gz" | tar -xz -C "$t"
  mkdir -p "$HOME/.local/bin"; mv "$t"/gh_*/bin/gh "$HOME/.local/bin/gh"; rm -rf "$t"
fi
command -v git >/dev/null || { echo "install.sh: git is missing; install it (it needs sudo) and run again" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web < /dev/tty
gh auth setup-git
if [ -d "$DEST/.git" ]; then git -C "$DEST" pull --ff-only -q || true; else gh repo clone "$PRIVATE" "$DEST"; fi
exec bash "$DEST/claude/install/agent.sh" "$@"
