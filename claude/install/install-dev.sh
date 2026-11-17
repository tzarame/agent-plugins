#!/usr/bin/env bash
# install-dev.sh - install.sh --dev: the dev copy of the private part, in ~/.agent-kit-dev with the command
# ~/start-dev.sh; it runs the latest pre-release vX.Y.Z-rc.N. ~/.agent-kit and ~/start.sh are not touched.
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
bash "$main" --dev
