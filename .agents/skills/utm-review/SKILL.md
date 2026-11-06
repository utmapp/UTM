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
  `Co-authored-by`** (strip it — a human takes full responsibility for the
  code). Verify with `git log --format='%H%n%B' "$base"..HEAD`.
- **Scope discipline.** One feature/fix; no edits, refactors, reformatting, or
  whitespace/header churn in unrelated files; no stray logging.
- **Generated files not hand-edited** — `Configuration/QEMUConstantGenerated.swift`,
  `Scripting/UTMScripting.swift`, QAPI/QMP wrappers. Edit the generator instead.
- **Logging** goes through `UTMLogging`/`logging` at `debug` level (warnings and
  errors excepted); bring-up-only logging is removed before committing.
- **Testing evidence** (rule 3), only for diffs that change code. Check the
  evidence against rule 3's wording: how the test was done, before/after for a
  fix, every code path including errors for a feature, and screenshots where it
  asks for them. Look for evidence from `/utm-test` in this session, the
  branch's evidence folder (`utm-test-evidence/<branch>` under
  `git rev-parse --path-format=absolute --git-common-dir`; read its
  `notes.md`), the user, or the body of an existing PR via `gh pr view`. It
  must cover the current diff, not an earlier revision. Recompute the
  fingerprint the way utm-test describes it, against the merge-base of `HEAD` and utmapp/UTM's `main`, using whichever remote points at utmapp/UTM (not necessarily `origin`). If it
  doesn't match the one in `notes.md`, the code changed after testing, so
  judge whether that change needs testing again. If it's missing, flag it as a blocker for `/utm-submit`.
  The all-configurations UI screenshots are optional, so suggest them but don't
  block on them. Prose-only diffs (docs, translations, skill text) don't need
  testing, but commands or scripts in them that people or agents will run do.
  CI configuration and scripts count as code.
- **UI strings** avoid jargon ("GPU Acceleration" not "Venus", "Apple Silicon"
  not ARM64); commit titles are `component: short description` explaining *why*.
- **Tests.** Not every change needs one, but the ones below do; the test suite's
  layout and commands are in `Tests/README.md`. Flag a missing test as a finding
  that names the tier it belongs in. Judge by what the diff touches:

  | The change | Test it needs | Where |
  |---|---|---|
  | How a configuration turns into QEMU arguments, is encoded, or migrates (`Configuration/`) | A unit test on the configuration: an argument sub-sequence through `QemuArgumentTestCase`, a `config.plist` fixture that round-trips, or a legacy fixture that migrates | `Tests/Shared/Configuration/` |
  | A rule of a settings or wizard view (what a toggle enables, a default, a clamp, a cascade) | The rule as a function on the configuration or `VMWizardState`, tested as a plain unit test; a ViewInspector test only when the bug is the view's wiring (a disabled control, a line limit, a picker binding) | `Tests/Shared/Views/`, rules next to the type they belong to |
  | The VM list, registry, downloads, scripting records, remote messages (`Platform/UTMData.swift`, `Services/`) | A hosted unit test with its own storage (`TestStorage`, `UTMRegistry(defaults:)`), covering the error path too | `Tests/Shared/Platform/`, `Tests/Shared/Services/` |
  | Starting, stopping, pausing, saving or restoring a QEMU VM (`Services/UTMQemuVirtualMachine.swift`, the launch path) | A scenario in `VMLifecycleTests` when the signed host can show it (it boots the firmware shell; a disk image, a serial port and a saved state are available); otherwise the manual test rule 3 asks for, described in the PR | `Tests/macOS/` |
  | A control or flow of the library, wizard or settings (a value set in one screen that another screen must keep, an alert that must appear) | A flow in the UI tests, on both platforms when both have the screen; every new interactive control gets an identifier in `UTMAccessibilityID` | `Tests/UITests/macOS/`, `Tests/UITests/iOS/` |
  | A layout fix on a current OS (something cut off, misplaced, the wrong column) | A geometry assertion in `VMLayoutTests` when the symptom is measurable; the screenshots of rule 3c otherwise | `Tests/UITests/` |
  | Generated sources, `UTM.sdef`, `Localizable.strings`, `Settings.bundle`, the project file | The static checks (`sh Tests/Static/run_all.sh`), extended when a new kind of mistake slipped through | `Tests/Static/` |

  No test is expected for translations, documentation, comments, a pure refactor
  that the existing tests still cover, dependency bumps, or the AppKit and UIKit
  display window controllers (they need a real display; the manual test of rule 3
  stands in). CI configuration and scripts are code and need a run, not a test.

  A test for a bug fix is named after the fix only once it has been shown to fail
  with the fix reverted and pass with it restored (`git revert --no-commit <fix>`);
  the PR says so. Tests never sleep for a fixed time: they poll with a deadline.
  A test the host cannot run skips with the reason rather than failing.

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

First clean up old testing evidence. `/utm-test` keeps one folder per branch
under `utm-test-evidence/` in the git dir, and `/utm-submit` deletes a folder
once its PR is written. Folders left behind come from branches that no longer
exist, so remove those:

```sh
root="$(git rev-parse --path-format=absolute --git-common-dir)/utm-test-evidence"
[ -d "$root" ] && find "$root" -type f -name meta | while read -r m; do
  b=$(sed -n 's/^branch=//p' "$m"); d=$(dirname "$m")
  [ -n "$b" ] && ! git show-ref --verify --quiet "refs/heads/$b" || continue
  echo "removing evidence for $b"
  find "$d" -mindepth 1 -maxdepth 1 -type f -delete; rmdir "$d" 2>/dev/null
done
```

This deletes only the files in a stale folder, never its subfolders, which may
hold evidence for a live branch such as `foo/bar` under a deleted `foo`.

List any removed folders in the report.

If Step 4 found that the current branch's evidence no longer matches the change
(for example, the fix was rewritten since it was tested), say so in the report
and ask the user before deleting it. Before-fix screenshots often stay valid
and are slow to recreate.

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
