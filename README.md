# agent-plugins

Plugins for AI agents, one folder per tool, since each has its own plugin format.

## Claude Code (`claude/`)

| Path | What |
|---|---|
| `claude/plugins/auditor` | `/auditor:github`, `:code`, `:docs`, `:security`, `:architecture`, `:all`, each with `[--model M] [--effort E]`: an auditor subagent (Sonnet at high effort by default, a 200k window of its own) audits one area of the project and files each problem as a GitHub issue; only the number of issues comes back to the session |
| `claude/plugins/unstoppable` | `/unstoppable:on`, `:off`, `:status`: off by default, per project. When on, a session idle for 5 minutes is woken with "Decide yourself. Maybe the code needs a review.", at most 3 times in a row; a message of the user resets the count. It takes effect at once |
| `claude/install/install.sh` | the setup of a machine, run once and again to update: installs the GitHub CLI and signs in, then the private setup (packages, Claude Code, the project) and `~/start.sh`, which starts the project's session. It starts nothing itself |
| `claude/install/install-dev.sh` | the same setup for the `dev` branch of the private part: it goes to `~/.ai-tools-dev` and the command is `~/start-dev.sh`. `~/.ai-tools` and `~/start.sh` are not touched. `install.sh` takes any branch with `AGENT_SETUP_BRANCH` |

First step on a new machine (downloads the script and makes it executable, since downloads come without the exec bit). Then start a project with `~/start.sh`:

```
curl -fsSL https://raw.githubusercontent.com/tzarame/agent-plugins/main/claude/install/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

The plugins are installed by `~/start.sh` (from the private `ai-tools` marketplace, as `auditor@ai-tools` and `unstoppable@ai-tools`), not by hand. The copies in this repository are the old ones; `start.sh` removes them.

Neither plugin depends on anything but Claude Code, git and, for `auditor`, the GitHub CLI.
