#!/usr/bin/env bash
# install-dev.sh - the same setup as install.sh, for the dev branch of the private part: it goes to
# ~/.ai-tools-dev and the command is ~/start-dev.sh. ~/.ai-tools and ~/start.sh (main) are not touched.
# It runs the install.sh beside it, or downloads it when it is alone.
#
#   first run:  curl -fsSL https://raw.githubusercontent.com/tzarame/agent-plugins/main/claude/install/install-dev.sh -o install-dev.sh
#               less install-dev.sh      # read what runs
#               bash install-dev.sh
#   then:       ~/start-dev.sh [PROJECT] [options]
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P); main="$here/install.sh"
if [ ! -f "$main" ]; then
  main=$(mktemp); trap 'rm -f "$main"' EXIT
  curl -fsSL https://raw.githubusercontent.com/tzarame/agent-plugins/main/claude/install/install.sh -o "$main"
fi
AGENT_SETUP_BRANCH=dev bash "$main"
