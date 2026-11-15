---
description: Audit the code with a strong model; each problem becomes a GitHub issue
argument-hint: "[--model M] [--effort E]"
---
Options given: $ARGUMENTS
Model: the value after --model, else sonnet. Effort: the value after --effort, else high.

Start the auditor:auditor subagent with that model and effort, and this task:
Audit its code: bugs, dead code, weak spots of this project. File each problem you find as an issue on GitHub. Change nothing else. Reply only with the number of issues you filed.

Tell the user only that number.
