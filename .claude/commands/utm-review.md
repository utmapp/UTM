---
description: Review pending UTM changes (standard code review + CONTRIBUTING.md/AGENTS.md audit) before submitting. Run before /utm-submit.
argument-hint: [low|medium|high|max]
allowed-tools: Bash, Read, Grep, Glob, Skill, Task
---

Read and follow the canonical, agent-neutral workflow in
`.agents/skills/utm-review/SKILL.md`, executing its steps end to end.

Claude Code specifics:
- For the Step 3 standard code review, invoke the `code-review` skill at the
  effort level passed here (default `high`).
- Argument passed to this command (review effort, if any): $ARGUMENTS
