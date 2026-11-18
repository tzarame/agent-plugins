#!/usr/bin/env bash
# install.sh - the GitHub part only: git and the GitHub CLI if missing (no root), the sign-in to the
# agents' GitHub App if not done (or the App's own key), the private part (zog88/agent-kit, in ~/.agent-kit), and ~/start.sh.
# Packages, Claude, Tailscale and the project are set up by ~/start.sh (launcher/agent.sh), not here.
# Nothing private is in this file.
# The sign-in prints a code and a link; open the link, enter the code, allow the App. The token
# reaches only the repositories the App is installed on, and no more than the person may do there.
# It stays on this machine only (~/.config/agent-kit/git-credentials, mode 600). Without a Client ID
# set, it logs in to GitHub instead (gh auth login).
# It first tries to read the private part with what is on the machine: the App's key
# (~/.config/agent-kit/app-key.pem), then the token of a sign-in before. With neither it asks: paste the App's key
# (the agent then acts as the App itself, and your own gh login on this machine is signed out), or sign in
# yourself with a code (for your personal projects only).
#
#   first run:  curl -fsSL https://raw.githubusercontent.com/tzarame/agent-plugins/main/claude/install/install.sh -o install.sh
#               less install.sh      # read what runs
#               bash install.sh
#               bash install.sh --dev   # the dev copy instead: ~/.agent-kit-dev and ~/start-dev.sh, on pre-releases
#   then:       ~/start.sh [PROJECT] [options]     sets up what is missing, then starts the session
set -euo pipefail
PRIVATE=${AGENT_SETUP_REPO:-zog88/agent-kit}
# the lines of the log, as the launcher writes them: a heading, then its steps under it (done, not done, a plain line).
# Colours only on a terminal (NO_COLOR turns them off)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then C_OK=$'\e[32m' C_NO=$'\e[31m' C_B=$'\e[1m' C_0=$'\e[0m'; else C_OK="" C_NO="" C_B="" C_0=""; fi
say() { printf '\n%s== %s%s\n' "$C_B" "$*" "$C_0"; }
ok() { printf '  %s✓%s %s\n' "$C_OK" "$C_0" "$*"; }
info() { printf '  %s\n' "$*"; }
die() { printf '  %s✗%s %s\n' "$C_NO" "$C_0" "$*" >&2; exit 1; }
[ "$(id -u)" = 0 ] && die "Run this as your normal user, not with sudo or as root: the agent, its logins and its files belong to that user. It asks for sudo itself, only for missing packages."
# the channel of the private part (its README, "The stable and the dev copy"): stable goes to ~/.agent-kit and
# ~/start.sh and runs the latest release vX.Y.Z; --dev goes to ~/.agent-kit-dev and ~/start-dev.sh and runs the
# latest pre-release vX.Y.Z-rc.N. Both are clones of main; the launcher moves them to their tag at each start.
CHANNEL=stable
case "${1:-}" in
  --dev) CHANNEL=dev ;;
  "") ;;
  *) die "unknown option $1 (the only one is --dev)" ;;
esac
if [ "$CHANNEL" = dev ]; then SUF="-dev"; else SUF=""; fi
DEST="$HOME/.agent-kit$SUF"; START="$HOME/start$SUF.sh"
CLIENT_ID=${AGENT_SETUP_CLIENT_ID:-Iv23lijFlkviWDqdzKMP}   # the Client ID of the agents' GitHub App; not a secret
export PATH="$HOME/.local/bin:$PATH"
say "GitHub"
if ! command -v gh >/dev/null; then   # the GitHub CLI as a user program, no sudo
  arch=$(uname -m); case $arch in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) die "no GitHub CLI is built for $arch; install gh yourself and run again" ;; esac
  v=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -1) || v=""
  [ -n "$v" ] || die "could not learn the latest version of the GitHub CLI (no network, or GitHub's limit of requests); run again later, or install gh yourself"
  t=$(mktemp -d); curl -fsSL "https://github.com/cli/cli/releases/download/v$v/gh_${v}_linux_$arch.tar.gz" | tar -xz -C "$t"
  mkdir -p "$HOME/.local/bin"; mv "$t"/gh_*/bin/gh "$HOME/.local/bin/gh"; rm -rf "$t"
  ok "GitHub CLI $v installed in ~/.local/bin"
fi
# git without root on Debian or Ubuntu: apt-get download fetches the packages as the user, dpkg -x
# unpacks them under ~/.local/pkg, and a small ~/.local/bin/git tells git where its parts are
if ! command -v git >/dev/null; then
  command -v apt-get >/dev/null || die "git is missing; install it and run again"
  info "git is missing; installing it in your home folder, without root"
  pre="$HOME/.local/pkg"; t=$(mktemp -d); mkdir -p "$pre" "$HOME/.local/bin"
  need=$(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances git 2>/dev/null \
    | grep '^[a-z0-9]' | sort -u | while read -r p; do dpkg -s "$p" >/dev/null 2>&1 || echo "$p"; done)
  (cd "$t" && apt-get download -q $need) >/dev/null || { rm -rf "$t"; die "could not download git ($need)"; }
  for d in "$t"/*.deb; do dpkg -x "$d" "$pre"; done; rm -rf "$t"
  cat > "$HOME/.local/bin/git" <<SH
#!/bin/sh
p="$pre"
export GIT_EXEC_PATH="\$p/usr/lib/git-core" GIT_TEMPLATE_DIR="\$p/usr/share/git-core/templates"
export LD_LIBRARY_PATH="\$(echo "\$p"/usr/lib/*-linux-gnu | tr ' ' ':')\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "\$p/usr/bin/git" "\$@"
SH
  chmod +x "$HOME/.local/bin/git"
  git --version >/dev/null || die "git does not start"
  ok "git installed in ~/.local/pkg"
fi
CONF="$HOME/.config/agent-kit"; CRED="$CONF/git-credentials"; URL="https://github.com/$PRIVATE.git"
mkdir -p "$CONF"; chmod 700 "$CONF"
helper="store --file=$CRED"   # the App's token, for this setup only
can_read() { [ -s "$CRED" ] && GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c "credential.helper=$helper" ls-remote "$URL" >/dev/null 2>&1; }
KEY="$CONF/app-key.pem"
# the App itself: a token of its installation on the private part's account (one hour), from the key $1.
# The App's pass goes to curl on its input, not in its arguments
b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
app_token() {
  local now h p s j id; now=$(date +%s)
  h=$(printf '{"alg":"RS256","typ":"JWT"}' | b64)
  p=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $((now - 60)) $((now + 540)) "$CLIENT_ID" | b64)
  s=$(printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -sign "$1" -binary 2>/dev/null | b64); j="$h.$p.$s"
  id=$(printf 'Authorization: Bearer %s\n' "$j" | curl -fsS -H @- -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$PRIVATE/installation" 2>/dev/null | field id | head -1)
  [ -n "$id" ] || return 1
  printf 'Authorization: Bearer %s\n' "$j" | curl -fsS -X POST -H @- -H "Accept: application/vnd.github+json" "https://api.github.com/app/installations/$id/access_tokens" 2>/dev/null | field token | head -1
}
helper_app='!f() { echo username=x-access-token; echo "password=$APP_TOK"; }; f'   # the token stays in the environment
APPMODE=0
can_read_app() {
  [ -s "${1:-$KEY}" ] && command -v openssl >/dev/null || return 1
  APP_TOK=$(app_token "${1:-$KEY}") && [ -n "$APP_TOK" ] || return 1
  export APP_TOK
  GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c "credential.helper=$helper_app" ls-remote "$URL" >/dev/null 2>&1
}
field() { sed -n "s/.*\"$1\": *\"\{0,1\}\([^\",}]*\).*/\1/p"; }   # one field of a flat JSON answer
if [ -z "$CLIENT_ID" ]; then
  info "No GitHub App is set for the setup (AGENT_SETUP_CLIENT_ID); logging in to GitHub instead."
  gh auth status >/dev/null 2>&1 || gh auth login --hostname github.com --git-protocol https --web < /dev/tty
  gh auth setup-git; ok "signed in to GitHub"; helper=$(git config --global --get-all credential.https://github.com.helper | tail -1)
elif can_read_app; then APPMODE=1; ok "signed in as the App itself (its key is on this machine): $PRIVATE can be read"
elif can_read; then ok "signed in already: $PRIVATE can be read"
else
  way=2
  if (: < /dev/tty) 2>/dev/null; then
    info "$PRIVATE cannot be read from this machine yet. Two ways:"
    info "  ${C_B}1$C_0  paste the key of the agents' GitHub App: the agent acts as the App itself."
    info "     Your own GitHub login on this machine (gh auth) is signed out."
    info "  ${C_B}2$C_0  sign in yourself, with a code: for your personal projects only"
    way=""; while [ "$way" != 1 ] && [ "$way" != 2 ]; do printf '  1 or 2: '; read -r way < /dev/tty || die "no answer; run again"; done
  fi
fi
if [ -n "$CLIENT_ID" ] && [ "$APPMODE" = 0 ] && [ "${way:-}" = 1 ]; then
  command -v openssl >/dev/null || die "openssl is missing; install it and run again"
  info "Paste the App's private key (the .pem file's text), then press Enter and Ctrl-D. It is not shown."
  trap 'stty echo < /dev/tty 2>/dev/null || true; rm -f "$KEY.new"' EXIT
  stty -echo < /dev/tty; k=$(cat < /dev/tty); stty echo < /dev/tty
  (umask 077; printf '%s\n' "$k" > "$KEY.new"); k=""
  openssl pkey -in "$KEY.new" -noout 2>/dev/null || die "that is not a private key; nothing changed"
  can_read_app "$KEY.new" || die "GitHub did not take the key for $PRIVATE (is it this App's key, and is the App installed there?); nothing changed"
  mv "$KEY.new" "$KEY"; trap - EXIT
  # the person's own login goes: the agent is the App only
  while gh auth status --hostname github.com >/dev/null 2>&1; do gh auth logout --hostname github.com < /dev/null >/dev/null 2>&1 || break; done
  rm -f "$CRED"
  APPMODE=1; ok "the key is in ${KEY/#$HOME/\~}; signed out of gh; $PRIVATE can be read as the App"
elif [ -n "$CLIENT_ID" ] && [ "${way:-}" = 2 ]; then
  # the device flow: a code to enter at a link, then the token
  r=$(curl -fsS -X POST -H "Accept: application/json" -d "client_id=$CLIENT_ID" https://github.com/login/device/code)
  dev=$(printf '%s' "$r" | field device_code); every=$(printf '%s' "$r" | field interval)
  info "Sign in as a member of ${PRIVATE%/*} and allow the App:"
  info "  open  $C_B$(printf '%s' "$r" | field verification_uri)$C_0"
  info "  code  $C_B$(printf '%s' "$r" | field user_code)$C_0"
  info "waiting for the sign-in..."
  tok=""
  for _ in $(seq 180); do
    sleep "${every:-5}"
    a=$(curl -fsS -X POST -H "Accept: application/json" -d "client_id=$CLIENT_ID&device_code=$dev&grant_type=urn:ietf:params:oauth:grant-type:device_code" https://github.com/login/oauth/access_token) || continue   # the network dropped for a moment: ask again
    tok=$(printf '%s' "$a" | field access_token); [ -n "$tok" ] && break
    case $(printf '%s' "$a" | field error) in
      authorization_pending) ;; slow_down) every=$(( ${every:-5} + 5 )) ;;
      *) die "the sign-in failed: $(printf '%s' "$a" | field error); run again" ;;
    esac
  done
  [ -n "$tok" ] || die "no sign-in in time; run again"
  (umask 077; printf 'https://x-access-token:%s@github.com\n' "$tok" > "$CRED"); tok=""
  can_read || { rm -f "$CRED"; die "that account cannot read $PRIVATE (is it a member with access, and is the App installed on it?)"; }
  ok "signed in: $PRIVATE can be read"
fi
[ "$APPMODE" = 0 ] || helper=$helper_app
say "agent-kit"
# an existing copy is updated by the launcher at each start (launcher/start.sh), so only a new copy is cloned here
if [ ! -d "$DEST/.git" ]; then git -c credential.helper= -c "credential.helper=$helper" clone -q -b main "$URL" "$DEST"
  ok "the $CHANNEL copy cloned to ${DEST/#$HOME/\~}"
  [ "$APPMODE" = 1 ] || { git -C "$DEST" config credential.helper ""; git -C "$DEST" config --add credential.helper "$helper"; }   # later pulls the same way
else ok "the $CHANNEL copy is in ${DEST/#$HOME/\~} (updated at each start)"
fi
if [ "$APPMODE" = 1 ]; then   # later pulls with the App's tokens, from the kit's own helper (launcher/gh-app.sh)
  if [ -f "$DEST/launcher/gh-app.sh" ]; then
    git -C "$DEST" config credential.helper ""; git -C "$DEST" config --add credential.helper "!bash $(printf '%q' "$DEST/launcher/gh-app.sh") git-credential"
    git -C "$DEST" config credential.useHttpPath true
  else info "this copy is older than the App's login (no launcher/gh-app.sh): it is not updated until it is cloned again"
  fi
fi
if [ "$CHANNEL" = dev ]; then git -C "$DEST" config agent-kit.channel dev; else git -C "$DEST" config --unset agent-kit.channel 2>/dev/null || true; fi
br=$(git -C "$DEST" symbolic-ref --short -q HEAD 2>/dev/null || true)
if [ -n "$br" ] && [ "$br" != main ]; then   # a copy on another branch is not moved by the launcher
  info "it is on the branch $br, so it is not updated. To follow the $CHANNEL channel: git -C $DEST switch main"
fi
# ~/start.sh: the one command. The launcher updates the private part, sets up what is missing, and starts the session.
sed "s#@DEST@#\$HOME/.agent-kit$SUF#g" > "$START.new" <<'WRAP'
#!/usr/bin/env bash
# start.sh (agent-kit start): runs agent.sh, which hands over to the launcher's start.sh: it updates the launcher and starts the project's session.
export PATH="$HOME/.local/bin:$PATH"
exec bash "@DEST@/launcher/agent.sh" "$@"
WRAP
chmod +x "$START.new"
# rewrite only when the content changed
if cmp -s "$START.new" "$START" 2>/dev/null; then rm -f "$START.new"; ok '~'"/start$SUF.sh is up to date"; else mv "$START.new" "$START"; ok '~'"/start$SUF.sh written"; fi
printf '\n  %snext: ~/start%s.sh [PROJECT] [options]%s\n' "$C_B" "$SUF" "$C_0"
