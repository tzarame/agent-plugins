#!/bin/sh
# idle-nudge.sh - an async Stop hook. When the project's unstoppable mode is on (.claude/unstoppable,
# set by /unstoppable:on), it waits NUDGE_SECONDS (300); if the session wrote nothing meanwhile, it
# wakes the model with two lines (exit 2): "Decide yourself." and "Maybe the code needs a review."
# At most NUDGE_MAX (3) nudges in a row; a prompt of the user resets the count (UserPromptSubmit).
in=$(cat)
cwd=$(printf '%s' "$in" | sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p')
root=$(cd "${cwd:-.}" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "${cwd:-.}")
[ -f "$root/.claude/unstoppable" ] || exit 0
id=$(printf '%s' "$in" | sed -n 's/.*"session_id" *: *"\([A-Za-z0-9_-]*\)".*/\1/p')
f="${TMPDIR:-/tmp}/unstoppable-nudge-$id"
if printf '%s' "$in" | grep -q '"hook_event_name" *: *"UserPromptSubmit"'; then rm -f "$f"; exit 0; fi
printf '%s' "$in" | grep -q '"agent_id"' && exit 0   # a subagent's stop, not the session's
t=$(printf '%s' "$in" | sed -n 's/.*"transcript_path" *: *"\([^"]*\)".*/\1/p')
[ -f "$t" ] || exit 0
n=$(cat "$f" 2>/dev/null || echo 0)
[ "$n" -ge "${NUDGE_MAX:-3}" ] && exit 0
sleep 5  # Claude Code writes the turn record just after the stop
before=$(stat -c %Y "$t")
sleep "${NUDGE_SECONDS:-300}"
[ "$(stat -c %Y "$t")" = "$before" ] || exit 0
echo $((n + 1)) > "$f"
printf 'Decide yourself.\nMaybe the code needs a review.\n' >&2
exit 2
