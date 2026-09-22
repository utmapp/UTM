---
description: Publish a new UTM GitHub release — drafts release notes since the last release, asks for approval, then bumps Build.xcconfig, tags, and creates the release + Releases discussion.
argument-hint: [version x.y.z (default next revision)] [prerelease yes|no (default yes)]
allowed-tools: Bash, Read, Grep, Glob, Edit, Write, AskUserQuestion
---

Read and follow `.agents/skills/utm-release/SKILL.md`. Use your scratchpad
directory as `$SCRATCH`. At the approval step, show the full notes as text,
then use AskUserQuestion to ask whether to publish, and treat any edits the user
asks for as another round. The trailer is `Assisted-by: Claude:<your model ID>`.

Arguments (version, then prerelease): $ARGUMENTS
