# agent-plugins

Plugins for AI agents, one folder per tool, since each has its own plugin format.

## Claude Code (`claude/`)

| Path | What |
|---|---|
| `claude/plugins/auditor` | `/auditor:github`, `:code`, `:docs`, `:security`, `:architecture`, `:all`, each with `[--model M] [--effort E]`: an auditor subagent (Sonnet at high effort by default, a 200k window of its own) audits one area of the project and files each problem as a GitHub issue; only the number of issues comes back to the session |
| `claude/plugins/unstoppable` | `/unstoppable:on`, `:off`, `:status`: off by default, per project. When on, a session idle for 5 minutes is woken with "Decide yourself. Maybe the code needs a review.", at most 3 times in a row; a message of the user resets the count. It takes effect at once |
| `claude/install/install.sh` | the first step of setting up a machine: installs the GitHub CLI, logs in, then hands over to a private setup |

Install the plugins (the marketplace is `tzarame`):

```
claude plugin marketplace add tzarame/agent-plugins
claude plugin install auditor@tzarame
claude plugin install unstoppable@tzarame
```

Neither plugin depends on anything but Claude Code, git and, for `auditor`, the GitHub CLI.
