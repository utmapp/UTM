---
description: Submit the current UTM change as a PR to utmapp/UTM — ensures /utm-review ran, then updates an existing PR (blame-squash + force-push) or opens a new one (issue links + human-test attestation).
argument-hint: [PR number or URL — for updates]
allowed-tools: Bash, Read, Grep, Glob, Skill, Task, AskUserQuestion
---

Read and follow the canonical, agent-neutral workflow in
`.agents/skills/utm-submit/SKILL.md`, executing its steps end to end.

Claude Code specifics:
- Where the workflow says "ask the user" for a fixed set of choices (e.g. the
  Step 1 review gate), use AskUserQuestion.
- To run the Step 1 review gate ("/utm-review now"), read and follow
  `.agents/skills/utm-review/SKILL.md`.
- For the interactive `gh auth login`, suggest the user type `! gh auth login`
  so its output lands in this session.
- Argument passed to this command (PR number or URL, if updating): $ARGUMENTS
