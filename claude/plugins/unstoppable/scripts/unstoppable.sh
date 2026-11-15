#!/bin/sh
# unstoppable.sh [on|off]: switch the unstoppable mode of this project, or say whether it is on.
# The mode is the file .claude/unstoppable at the root of the project; it is off by default.
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd); f="$root/.claude/unstoppable"
case "${1:-}" in
  on) mkdir -p "$root/.claude" && : > "$f" && echo "Unstoppable mode is on for $root: after 5 minutes idle, the session is woken up." ;;
  off) rm -f "$f" && echo "Unstoppable mode is off for $root." ;;
  *) [ -f "$f" ] && echo "Unstoppable mode is on for $root." || echo "Unstoppable mode is off for $root." ;;
esac
