---
name: utm-review
description: Review pending UTM changes before they are submitted. Runs a standard correctness/quality code review of the current branch's diff AND audits it against UTM's contribution rules in CONTRIBUTING.md and AGENTS.md — scope discipline, commit/PR format, AI attribution, logging hooks, generated files, UI/design philosophy, and platform compatibility. Use this before opening or updating a UTM pull request, whenever the user asks to review UTM changes, or when the user runs /utm-review. The /utm-submit workflow expects this to have been run on the current changes first.
---

# utm-review

Agent-neutral instructions — follow them with whatever tools your agent provides
(Claude Code, Codex, OpenCode, Antigravity, …). This is the canonical copy; the
per-agent entries under `.claude/commands/`, `.opencode/command/`, etc. just
point here.

Gate a UTM change through two passes before it can be submitted:

1. **A standard code review** for real correctness bugs and worthwhile cleanups.
2. **A UTM contribution-guideline audit** — the part specific to this project and
   the reason this workflow exists. UTM has firm rules (especially for
   AI-assisted contributions) that a generic review won't check.

Report everything you find. This workflow *reviews and reports*; it does not
push, commit, or rewrite history — that is `/utm-submit`'s job.

If you were invoked with an argument, treat it as a review effort level
(`low|medium|high|max`); default to `high`.

## Step 1 — Read the authoritative rules

Read `CONTRIBUTING.md` and `AGENTS.md` at the repo root now — they are the single
source of truth for what makes an acceptable UTM contribution, and Step 4 audits
the diff against them. (`AGENTS.md` overrides default tool behavior for this repo
— notably the commit-trailer policy.)

## Step 2 — Establish the review scope

The change under review is everything that will land in the PR: commits on this
branch since it diverged from the base, plus any uncommitted edits.

```sh
base=$(git merge-base HEAD origin/main)
git log --oneline "$base"..HEAD          # the PR's commits
git --no-stat diff "$base"...HEAD        # committed change
git --no-stat diff HEAD                  # uncommitted change (if any)
git status --porcelain                   # untracked files
```

Keep the list of changed files handy — several guideline checks below hinge on
*which* files were touched.

## Step 3 — Standard code review

Run a standard code review of the pending diff to surface correctness bugs and
reuse/simplification/efficiency cleanups. Use whatever review capability your
agent provides — for example a `/code-review` or `/review` command — or perform a
focused review pass yourself if none exists. If the change includes uncommitted
edits the review tool doesn't pick up, review those yourself to the same
standard. Collect the findings; you'll merge them into one report.

## Step 4 — UTM contribution-guideline audit

Audit the diff against **every** rule in the `CONTRIBUTING.md` and `AGENTS.md` you
just read — those files *are* the checklist, so keeping it there (rather than
copied here) means it never drifts out of sync. Cite `file:line` and the specific
rule for each issue you raise. Judge the diff against all of it: style and
concurrency, design philosophy, platform compatibility, dependency-upstreaming,
and the rest — defer to the files' wording instead of restating it.

These few are high-value, repo-specific, and the easiest to miss, so check them
explicitly:

- **AI attribution.** Every AI-assisted commit in `"$base"..HEAD` **must** carry an
  `Assisted-by: AGENT:MODEL` trailer — many agents omit it by default, so a missing
  trailer is a common, easy-to-miss finding, not an acceptable absence — and **no
  `Co-authored-by`** (strip it — UTM takes full human responsibility per the
  Linux-kernel policy). Verify with `git log --format='%H%n%B' "$base"..HEAD`.
- **Scope discipline.** One feature/fix; no edits, refactors, reformatting, or
  whitespace/header churn in unrelated files; no stray logging.
- **Generated files not hand-edited** — `Configuration/QEMUConstantGenerated.swift`,
  `Scripting/UTMScripting.swift`, QAPI/QMP wrappers. Edit the generator instead.
- **Logging** goes through `UTMLogging`/`logging` at `debug` level (warnings and
  errors excepted); bring-up-only logging is removed before committing.
- **UI strings** avoid jargon ("GPU Acceleration" not "Venus", "Apple Silicon"
  not ARM64); commit titles are `component: short description` explaining *why*.

## Step 5 — Report

Produce one consolidated report:

- A one-line summary of the change and its apparent scope.
- **Correctness/quality findings** (from Step 3), each with `file:line`.
- **Guideline findings** (from Step 4), each with `file:line` and the rule cited.
- A short verdict: is this ready to submit, or what must change first? Call out
  any blocker that `/utm-submit` will trip on (e.g. a `Co-authored-by` trailer,
  an unrelated-file edit, or a missing `Assisted-by`).

Be honest about uncertainty and avoid nitpicks a senior reviewer wouldn't raise
(pre-existing issues, things a compiler/linter would catch, lines the change
didn't touch). The goal is a change that sails through human review on the UTM
repo, not a wall of pedantry.

## Step 6 — Record that the review ran (handoff to /utm-submit)

`/utm-submit` checks whether the current changes were reviewed. Leave a marker so
it can confirm even across sessions or a different agent:

```sh
gitdir=$(git rev-parse --git-dir)
hash=$( { git rev-parse HEAD; git diff "$(git merge-base HEAD origin/main)"...HEAD; git diff HEAD; } | git hash-object --stdin )
printf 'branch=%s\nhead=%s\ndiff_hash=%s\nat=%s\n' "$(git rev-parse --abbrev-ref HEAD)" "$(git rev-parse HEAD)" "$hash" "$(date -u +%FT%TZ)" > "$gitdir/utm-review-marker"
```

Then end with a clear, recognizable line, e.g.:
`✅ utm-review complete — <branch> @ <short-sha>, N findings (M blockers).`

The `diff_hash` lets `/utm-submit` tell whether the changes it's about to submit
are exactly the ones you reviewed, or whether they've been edited since.
