#!/usr/bin/env bash
# install.sh - the GitHub part only: git and the GitHub CLI if missing (no root), the sign-in to the
# agents' GitHub App if not done, the private part (zog88/ai-tools, in ~/.ai-tools), and ~/start.sh.
# Packages, Claude, Tailscale and the project are set up by ~/start.sh (launcher/agent.sh), not here.
# Nothing private is in this file.
# The sign-in prints a code and a link; open the link, enter the code, allow the App. The token
# reaches only the repositories the App is installed on, and no more than the person may do there.
# It stays on this machine only (~/.config/ai-tools/git-credentials, mode 600). Without a Client ID
# set, it logs in to GitHub instead (gh auth login).
#
#   first run:  curl -fsSL https://raw.githubusercontent.com/tzarame/agent-plugins/main/claude/install/install.sh -o install.sh
#               less install.sh      # read what runs
#               bash install.sh
#   then:       ~/start.sh [PROJECT] [options]     sets up what is missing, then starts the session
set -euo pipefail
[ "$(id -u)" = 0 ] && { echo "Run this as your normal user, not with sudo or as root: the agent, its logins and its files belong to that user. It asks for sudo itself, only for missing packages." >&2; exit 1; }
PRIVATE=${AGENT_SETUP_REPO:-zog88/ai-tools}
# the branch of the private part: main goes to ~/.ai-tools and ~/start.sh; another branch (install-dev.sh
# gives dev) goes to its own folder and its own command, so the main copy is not touched
BRANCH=${AGENT_SETUP_BRANCH:-main}
[[ $BRANCH =~ ^[A-Za-z0-9._-]+$ ]] || { echo "install.sh: the branch name has characters not allowed: $BRANCH" >&2; exit 1; }
if [ "$BRANCH" = main ]; then SUF=""; else SUF="-$BRANCH"; fi
DEST="$HOME/.ai-tools$SUF"; START="$HOME/start$SUF.sh"
CLIENT_ID=${AGENT_SETUP_CLIENT_ID:-Iv23lijFlkviWDqdzKMP}   # the Client ID of the agents' GitHub App; not a secret
export PATH="$HOME/.local/bin:$PATH"
if ! command -v gh >/dev/null; then   # the GitHub CLI as a user program, no sudo
  arch=$(uname -m); case $arch in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; esac
  v=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1)
  t=$(mktemp -d); curl -fsSL "https://github.com/cli/cli/releases/download/v$v/gh_${v}_linux_$arch.tar.gz" | tar -xz -C "$t"
  mkdir -p "$HOME/.local/bin"; mv "$t"/gh_*/bin/gh "$HOME/.local/bin/gh"; rm -rf "$t"
fi
# git without root on Debian or Ubuntu: apt-get download fetches the packages as the user, dpkg -x
# unpacks them under ~/.local/pkg, and a small ~/.local/bin/git tells git where its parts are
if ! command -v git >/dev/null; then
  command -v apt-get >/dev/null || { echo "install.sh: git is missing; install it and run again" >&2; exit 1; }
  echo "git is missing; installing it in your home folder, without root"
  pre="$HOME/.local/pkg"; t=$(mktemp -d); mkdir -p "$pre" "$HOME/.local/bin"
  need=$(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances git 2>/dev/null \
    | grep '^[a-z0-9]' | sort -u | while read -r p; do dpkg -s "$p" >/dev/null 2>&1 || echo "$p"; done)
  (cd "$t" && apt-get download -q $need) >/dev/null || { echo "install.sh: could not download git ($need)" >&2; rm -rf "$t"; exit 1; }
  for d in "$t"/*.deb; do dpkg -x "$d" "$pre"; done; rm -rf "$t"
  cat > "$HOME/.local/bin/git" <<SH
#!/bin/sh
p="$pre"
export GIT_EXEC_PATH="\$p/usr/lib/git-core" GIT_TEMPLATE_DIR="\$p/usr/share/git-core/templates"
export LD_LIBRARY_PATH="\$(echo "\$p"/usr/lib/*-linux-gnu | tr ' ' ':')\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "\$p/usr/bin/git" "\$@"
SH
  chmod +x "$HOME/.local/bin/git"
  git --version >/dev/null || { echo "install.sh: git does not start" >&2; exit 1; }
fi
CONF="$HOME/.config/ai-tools"; CRED="$CONF/git-credentials"; URL="https://github.com/$PRIVATE.git"
mkdir -p "$CONF"; chmod 700 "$CONF"
helper="store --file=$CRED"   # the App's token, for this setup only
can_read() { [ -s "$CRED" ] && GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c "credential.helper=$helper" ls-remote "$URL" >/dev/null 2>&1; }
field() { sed -n "s/.*\"$1\": *\"\{0,1\}\([^\",}]*\).*/\1/p"; }   # one field of a flat JSON answer
if [ -z "$CLIENT_ID" ]; then
  echo "No GitHub App is set for the setup (AGENT_SETUP_CLIENT_ID); logging in to GitHub instead."
  gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web < /dev/tty
  gh auth setup-git; helper=$(git config --global --get-all credential.https://github.com.helper | tail -1)
elif ! can_read; then
  # the device flow: a code to enter at a link, then the token
  r=$(curl -fsS -X POST -H "Accept: application/json" -d "client_id=$CLIENT_ID" https://github.com/login/device/code)
  dev=$(printf '%s' "$r" | field device_code); every=$(printf '%s' "$r" | field interval)
  echo "Open $(printf '%s' "$r" | field verification_uri) and enter the code $(printf '%s' "$r" | field user_code)"
  echo "(sign in as a member of ${PRIVATE%/*} and allow the App). Waiting..."
  tok=""
  for _ in $(seq 180); do
    sleep "${every:-5}"
    a=$(curl -fsS -X POST -H "Accept: application/json" -d "client_id=$CLIENT_ID&device_code=$dev&grant_type=urn:ietf:params:oauth:grant-type:device_code" https://github.com/login/oauth/access_token)
    tok=$(printf '%s' "$a" | field access_token); [ -n "$tok" ] && break
    case $(printf '%s' "$a" | field error) in
      authorization_pending) ;; slow_down) every=$(( ${every:-5} + 5 )) ;;
      *) echo "install.sh: sign-in failed: $(printf '%s' "$a" | field error)" >&2; exit 1 ;;
    esac
  done
  [ -n "$tok" ] || { echo "install.sh: no sign-in in time; run again" >&2; exit 1; }
  (umask 077; printf 'https://x-access-token:%s@github.com\n' "$tok" > "$CRED"); tok=""
  can_read || { rm -f "$CRED"; echo "install.sh: that account cannot read $PRIVATE (is it a member with access, and is the App installed on it?)" >&2; exit 1; }
fi
# an existing copy is updated by the launcher at each start (launcher/start.sh), so only a new copy is cloned here
if [ ! -d "$DEST/.git" ]; then git -c credential.helper= -c "credential.helper=$helper" clone -q -b "$BRANCH" "$URL" "$DEST"
  git -C "$DEST" config credential.helper ""; git -C "$DEST" config --add credential.helper "$helper"   # later pulls the same way
fi
# ~/start.sh: the one command. The launcher updates the private part, sets up what is missing, and starts the session.
sed "s#@DEST@#\$HOME/.ai-tools$SUF#g" > "$START.new" <<'WRAP'
#!/usr/bin/env bash
# start.sh (ai-tools start): runs agent.sh, which hands over to the launcher's start.sh: it updates the launcher and starts the project's session.
export PATH="$HOME/.local/bin:$PATH"
exec bash "@DEST@/launcher/agent.sh" "$@"
WRAP
chmod +x "$START.new"
# rewrite only when the content changed
if cmp -s "$START.new" "$START" 2>/dev/null; then rm -f "$START.new"; else mv "$START.new" "$START"; fi
echo "GitHub is set up. Start the session with: ~/start$SUF.sh [PROJECT] [options]"
