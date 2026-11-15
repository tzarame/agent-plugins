---
description: Audit every area of the project in turn with a strong model; each problem becomes a GitHub issue
argument-hint: "[--model M] [--effort E]"
---
Options given: $ARGUMENTS
Model: the value after --model, else sonnet. Effort: the value after --effort, else high.

For each area in turn (code; documentation against the code; security; architecture; GitHub issues and pull requests), start the auditor:auditor subagent with that model and effort, and this task:
Audit <the area> of this project. File each problem you find as an issue on GitHub. Change nothing else. Reply only with the number of issues you filed.

Tell the user only the number of issues for each area.
