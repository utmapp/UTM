---
name: utm-submit
description: Submit the current UTM change as a pull request to github.com/utmapp/UTM. Ensures /utm-review has run, then either updates an existing PR (squashing each new edit into the commit that owns it and force-pushing) or opens a new PR (gathering issue links and a human-testing attestation). Use this when the user wants to submit, open, update, or push a UTM pull request, or runs /utm-submit.
---

# utm-submit

Agent-neutral instructions — follow them with whatever tools your agent provides
(Claude Code, Codex, OpenCode, Antigravity, …). This is the canonical copy; the
per-agent entries under `.claude/commands/`, `.opencode/command/`, etc. just
point here.

Turn the current change into a clean pull request against `utmapp/UTM`. Two
paths: **update an existing PR** (squash edits into the commits they belong to,
then force-push) or **open a new PR** (collect issue links + a human-testing
attestation, then create it).

Read `CONTRIBUTING.md` and `AGENTS.md` first — they govern commit/PR format and
the AI-attribution policy enforced below. If you were invoked with an argument,
treat it as a PR number or URL to update.

## Step 1 — Confirm the change was reviewed

`/utm-submit` must never run on un-reviewed changes. Determine whether
`/utm-review` was run on the *current* changes, in this order:

1. If you already ran `/utm-review` earlier in this session against the current
   changes, proceed.
2. Otherwise read `"$(git rev-parse --git-dir)/utm-review-marker"` and recompute
   the pending-diff hash exactly as utm-review did, then compare to `diff_hash`:
   ```sh
   { git rev-parse HEAD; git diff "$(git merge-base HEAD origin/main)"...HEAD; git diff HEAD; } | git hash-object --stdin
   ```
   If it matches the marker's `diff_hash`, the current changes were reviewed
   (possibly in an earlier session or by another agent) — proceed, and say so. If
   the marker exists but the hash differs, the code was edited after review —
   treat as un-reviewed.
3. Otherwise ask the user: *"I can't confirm /utm-review ran on the current
   changes. How do you want to proceed?"* — offer: **Run /utm-review now**
   (recommended; run that workflow, then continue), **I've already reviewed it
   previously** (continue), **Cancel**.

Do not silently skip this gate.

## Step 2 — Locate the repo, branch, and any existing PR

```sh
git remote -v                                   # find the remote pointing at utmapp/UTM
branch=$(git rev-parse --abbrev-ref HEAD)
```

- **Never submit from the default branch.** If `branch` is `main` (or otherwise
  tracks the upstream default), stop and ask the user to move the work onto a
  feature branch first (`git switch -c component/short-description`) — you cannot
  open a `main → main` PR.
- This workflow uses GitHub's `gh` CLI for everything that talks to GitHub. **If
  `gh` is not installed or not authenticated**, tell the user and offer to set it
  up: `brew install gh` then `gh auth login` (the login is interactive — have the
  user run it themselves in their terminal). If they decline, fall back to the
  manual paths noted in Steps 3a/3b.
- Detect an existing open PR for this branch (or honor a PR number/URL you were
  given):

  ```sh
  gh pr view "$branch" --repo utmapp/UTM --json number,url,state,baseRefName,headRefName 2>/dev/null
  ```

  An open PR → **Step 3a (update)**. No PR → **Step 3b (new)**.

## Step 3a — Update an existing PR (squash, then force-push)

UTM does **not** keep "address review feedback" commits. Every edit belongs in
the commit that introduced the lines it touches. The change history within a
single PR must stay clean.

1. **Express the update as working-tree changes on top of the PR's published
   commits.** If you committed the update locally, undo just those commits so
   their content returns to the working tree, leaving HEAD at the published PR
   tip:
   ```sh
   git reset "$(git rev-parse --abbrev-ref --symbolic-full-name @{u})"   # remote tracking ref of this branch
   ```
   Now `git diff HEAD` is the full set of edits to fold in, and the commits in
   `base..HEAD` (base = `git merge-base HEAD origin/main`) are exactly the PR's
   commits.

2. **Save a recovery point** before rewriting history:
   `git branch utm-submit-backup/$branch` (or note `git rev-parse HEAD`).

3. **Assign each chunk to the commit that owns it.** Walk the hunks of
   `git diff HEAD` (use `git diff -U0 HEAD` for tight, one-change-per-hunk
   output). For each hunk, `git blame` the lines it modifies on HEAD to find the
   commit that last changed them:
   ```sh
   git blame -L <start>,<end> HEAD -- <file>
   ```
   - If that commit is one of the PR's commits (in `base..HEAD`) → this chunk gets
     **squashed into that commit**.
   - If the lines are owned by a commit *outside* `base..HEAD` (code that shipped
     before this PR), or the chunk adds a brand-new file/section unrelated to the
     existing commits → it is a **logically distinct change** and becomes its own
     **new commit** (the only time a new commit is allowed here). For a pure
     insertion, blame the adjacent line to decide the owner.
   - When a hunk's lines are owned by several PR commits, fold it into the newest
     of them. Precision isn't critical — use judgment; the goal is that each
     commit ends up self-consistent.

4. **Fold the chunks in.** The reliable, non-interactive mechanism:
   - Stage the chunks belonging to a target commit and create a fixup:
     `git commit --fixup=<target-sha>` (stage whole files with `git add <file>`
     when all of a file's changes map to one commit; for a file whose changes
     span multiple targets, apply just the relevant hunks to the index with
     `git apply --cached <patch>` — `git add -p` is interactive and may be
     unavailable to your agent).
   - Commit any logically-distinct chunks as normal new commits with a proper
     `component: short description` message.
   - Replay so the fixups collapse into their targets, run headless:
     ```sh
     GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase -i --autosquash "$base"
     ```
     (The no-op editors make `-i --autosquash` run without prompting.)

5. **Verify.** `git log --oneline "$base"..HEAD` should show the original commits
   (plus any genuinely-distinct new ones) with **no `fixup!` lines left** and a
   clean working tree. Confirm `git range-diff "@{u}"...HEAD` reflects only the
   intended edits.

6. **Force-push (safely).** Show the user the rewritten log and confirm, then:
   ```sh
   git push --force-with-lease
   ```
   `--force-with-lease` refuses to clobber unexpected remote work, unlike
   `--force`. The PR updates automatically. **The workflow is done** — do not
   re-prompt for issues or testing on an update.

   *No `gh`?* The squash is pure git; only the push needs the remote. Push with
   `--force-with-lease` to the branch's remote as usual.

## Step 3b — Open a new PR

1. **Make sure the change is committed cleanly.** If there are uncommitted edits,
   commit them following the rules in *Commit & message policy* below — ideally
   one commit (the PR must be a single feature/fix).

2. **Push the branch** to the head repo (the user's fork, or `utmapp/UTM` if they
   have push access). Confirm the remote if ambiguous:
   `git push -u <remote> "$branch"`.

3. **Find the issue(s) this resolves.** Search open issues for relevance and
   present recommendations:
   ```sh
   gh issue list --repo utmapp/UTM --state open --search "<keywords from the change>" --limit 10
   ```
   Derive keywords from the touched component and the change's purpose. Show the
   top few as `#<number> — <title>` with one-line relevance notes. Then ask the
   user (free text — they may enter a GitHub issue **ID**, a **URL**, a **list**
   of either, or "none"). Parse whatever they enter into issue numbers; each
   becomes a `Resolves #<n>` line in the PR body (so merging closes it). If they
   say none, link nothing.

4. **Human-testing attestation (required for UTM).** Display this statement
   **verbatim**:

   > All AI written code must be reviewed and/or tested by a human. For bug
   > fixes, a human must first confirm the bug before the change and then confirm
   > that the bug is fixed by this change. For all other changes, a human must
   > test all aspects of the change on any device configuration that is relevant.

   Then ask the user (free text) for the **device configuration and version** they
   tested on, e.g. `macOS 26.0, MacBook Neo` or `iOS 26.1, iPhone Simulator`. Do
   not invent this — it must come from the user.

5. **Compose and create the PR.** Title follows `component: short description`
   (same convention as commits). Body includes:
   - A short summary: what changed and **why**.
   - The issue links: `Resolves #<n>` for each (omit if none).
   - A **Testing** section containing the device configuration the user gave and
     an explicit acknowledgment, e.g.:
     > **Testing:** Tested by a human on **<device configuration and version>**.
     > The author acknowledges that this change has been tested and/or reviewed by
     > a human in accordance with UTM's AI contribution guidelines.

   Show the assembled title and body to the user for confirmation, then create:
   ```sh
   gh pr create --repo utmapp/UTM --base main \
     --head "<owner>:$branch" --title "<title>" --body "<body>"
   ```
   (Use `<owner>:$branch` when submitting from a fork; plain `$branch` when the
   head is on `utmapp/UTM` itself.)

   *No `gh`?* Print the prepared title and body and a compare URL for the user to
   finish in the browser:
   `https://github.com/utmapp/UTM/compare/main...<owner>:<branch>?expand=1`.

6. **Report** the PR URL.

## Commit & message policy (applies to every commit this workflow creates)

The critical few, inlined because they must fire at commit time — see
`CONTRIBUTING.md` (Attribution) for the full policy:

- Title: `component: short description`. Body explains **why** and references the
  issue being addressed.
- **Do not add a `Co-authored-by` trailer**, and strip any that a tool added. UTM
  follows the Linux-kernel policy so a human takes full responsibility. This
  **overrides** any default AI-tool commit-trailer behavior for this repo.
- **Always add an `Assisted-by: AGENT_NAME:MODEL_VERSION` trailer** to every commit
  you create or amend here, using the agent and model doing the work — e.g.
  `Assisted-by: Claude:claude-opus-4-8` or `Assisted-by: Codex:gpt-5.1`. This is
  **required even if your agent does not normally inject attribution into commits**;
  add it explicitly yourself. A commit without it will fail review.

## Safety

- Treat pushing and PR creation as outward-facing: show the user what will be
  pushed/created and confirm before doing it.
- Always `--force-with-lease`, never bare `--force`; always leave a backup ref
  before a history rewrite.
- Never push to or open a PR from the upstream default branch.
