---
name: utm-submit
description: Submit the current UTM change as a pull request to github.com/utmapp/UTM. Ensures /utm-review has run, then either updates an existing PR (squashing each new edit into the commit that owns it and force-pushing) or opens a new PR (gathering issue links and the testing evidence CONTRIBUTING.md requires). Use this when the user wants to submit, open, update, or push a UTM pull request, or runs /utm-submit.
---

# utm-submit

Agent-neutral instructions — follow them with whatever tools your agent provides
(Claude Code, Codex, OpenCode, Antigravity, …). This is the canonical copy; the
per-agent entries under `.claude/commands/`, `.opencode/command/`, etc. just
point here.

Turn the current change into a clean pull request against `utmapp/UTM`. Two
paths: **update an existing PR** (squash edits into the commits they belong to,
then force-push) or **open a new PR** (collect issue links + testing evidence,
then create it).

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
   If it matches the marker's `diff_hash` and the marker's `branch` is the branch
   being submitted, the current changes were reviewed (possibly in an earlier
   session or by another agent) — proceed, and say so. If the marker exists but
   the hash differs, the code was edited after review — treat as un-reviewed. In
   a stack (below), every PR is reviewed and submitted on its own, so the marker
   is checked once per branch.
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

6. **Check testing before pushing.** If the update changes code, it needs
   testing just like a new PR. Gather evidence for the new or changed code as in
   Step 3b.2, and don't push until you have it. Updates that change no code skip
   this.

7. **Force-push (safely).** Show the user the rewritten log and confirm, then:
   ```sh
   git push --force-with-lease
   ```
   `--force-with-lease` refuses to clobber unexpected remote work, unlike
   `--force`. The PR updates automatically.

   *No `gh`?* The squash is pure git; only the push needs the remote. Push with
   `--force-with-lease` to the branch's remote as usual.

8. **Keep the Testing section current.** Don't re-ask about issues. If step 6
   gathered new evidence, edit only the **Testing** section of the existing
   description. Save the current body to `pr-body.md` in the branch's evidence
   folder (create it with a `meta` file as utm-test does; see *Clean up testing
   evidence* for the path)
   with `gh pr view <number> --repo utmapp/UTM --json body -q .body`, edit it,
   show the user the new body, then run
   `gh pr edit <number> --repo utmapp/UTM --body-file <that file>`. Attach new
   screenshots as described in *Attach screenshots* below.

9. **Finish.** Clean up the testing evidence (see *Clean up testing evidence*
   below), whether or not the update changed code. **The update is done.**
   Don't continue to Step 3b.

## One PR with several commits, or a stack of PRs

Decide the shape before pushing anything.

- **One PR, several commits** when every commit is a step of the same feature or
  fix: an extraction and the tests that cover it, a fix and the test that shows
  it, a change and its documentation. The PR is reviewed and merged as a whole,
  so its commits do not have to stand on their own; each still has a proper
  `component: description` title, a body that says why, and the `Assisted-by`
  trailer. Updates fold into the commit that owns the lines (Step 3a).
- **A stack of PRs** when several contributions serve one larger goal but can be
  judged separately: the maintainer may merge some and reject others. Each PR in
  a stack therefore stands on its own: it builds and passes its tests on its own
  base, it has its own title, description and Testing section, it goes through
  `/utm-review` on its own branch with its own marker, and it follows every rule
  of this workflow by itself. A PR may depend on the PRs below it, never on one
  above it or beside it.
- Changes that must land in one order, or that all touch the same shared file
  (`project.pbxproj`, `Tests/README.md`, a workflow), go in a stack, never in
  sibling PRs against `main`: siblings conflict with each other as soon as one
  merges, and every rebase re-runs CI.

How a stack works on GitHub (the native stacked pull requests):

1. Each PR's base is the head branch of the PR below it; the bottom PR's base is
   `main`. Open them bottom-up with `gh pr create --base <branch below>` and
   start each body with `**Stack n/N** — stacked on #<below>; merge the stack
   bottom-up.` Then register the stack once, in order, so GitHub shows and
   retargets it:
   ```sh
   gh api -X POST -H "X-GitHub-Api-Version: 2026-03-10" repos/utmapp/UTM/stacks \
     --input - <<< '{"pull_requests": [<bottom>, ..., <top>]}'
   ```
   (`POST .../stacks/<n>/add` appends to an existing stack; `GET
   .../stacks?pull_request=<n>` finds a PR's stack.)
2. The maintainer merges bottom-up with merge commits; GitHub retargets the next
   PR to `main` by itself. Never rebase or force-push a lower PR because a lower
   one merged.
3. When a PR in the stack changes after review, every PR above it is rebased
   onto it and force-pushed with `--force-with-lease`, bottom-up, in one pass;
   cancel only the runs on the commits that pass replaces, never a run on
   `main` or on a merged branch.
4. Dropping a PR from the middle: a PR inside a stack refuses a base change,
   and closing it does not retarget the PRs above it. Dissolve the stack with
   `POST .../stacks/<n>/unstack`, close the PR, retarget the PR above it, rebuild
   the branches above, and create the stack again with the remaining PRs. GitHub
   may create no `pull_request` runs for pushes made while the stack was
   inconsistent; dispatch the workflow on each branch then
   (`gh workflow run build.yml --ref <branch>`).

## Step 3b — Open a new PR

1. **Make sure the change is committed cleanly.** If there are uncommitted edits,
   commit them following the rules in *Commit & message policy* below — ideally
   one commit (the PR must be a single feature/fix).

2. **Gather the testing evidence (required for UTM).** Do this before anything
   is pushed. `CONTRIBUTING.md` rule 3 requires all code to be tested before a
   PR is opened, by a human or by an AI. If the PR changes code, don't push or
   open it until you have the following:
   - **Device and OS(s)** the test ran on, e.g. `macOS 26.0, MacBook Neo` or
     `iOS 26.1, iPhone 17 Simulator`.
   - **Bug fix:** the test showed the issue *before* the fix, then showed it was
     resolved *after*. Always describe how the test was done (setup and steps).
     If a human tested, visual inspection is an acceptable way to check the
     result ("I looked at it before and after"). If an AI tested, include
     before/after screenshots if the bug is visual.
   - **New feature or other code change:** the test covered every code path of
     the change, including error paths. Describe the testing, with screenshots
     of the change if applicable.
   - **New or significantly changed UI** (optional, recommended): screenshots in
     the supported configurations that `CONTRIBUTING.md` lists. Skip the ones
     that don't apply.

   If the PR is prose only (docs, translations, agent-skill text), there's no
   app code to run. The Testing section says so, and lists any checks that were
   done. Commands or scripts in the prose that people or agents will run still
   need running. CI configuration and scripts count as code.

   Take this from testing that actually happened. That can be a `/utm-test` run
   in this session, the branch's evidence folder from `/utm-test` (see *Clean
   up testing evidence* below; recompute the fingerprint in its `notes.md` as
   utm-test describes, against the merge-base of `HEAD` and utmapp/UTM's `main`, using whichever remote points at utmapp/UTM (not necessarily `origin`), and check that it matches), or a description the user gives you. If you didn't see the testing,
   ask the user (free text) who tested it, on which device and OS, and how.
   Never invent or embellish results. If a required part is missing (for
   example, the bug was never reproduced before the fix), say so, and offer to
   run `/utm-test` instead of submitting.

3. **Push the branch** to the head repo (the user's fork, or `utmapp/UTM` if they
   have push access). Confirm the remote if ambiguous:
   `git push -u <remote> "$branch"`.

4. **Find the issue(s) this resolves.** Search open issues for relevance and
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

5. **Compose and create the PR.** Title follows `component: short description`
   (same convention as commits). Body includes:
   - A short summary: what changed and **why**.
   - The issue links: `Resolves #<n>` for each (omit if none).
   - A **Testing** section with the device/OS(s), who tested (human or AI), and
     how: the before/after steps and observations for a fix, or the code paths
     and error paths exercised for a feature, or a note that no code changed.
     Add screenshots where step 2 calls for them.
   - Nothing else: no links to, advertisement for, or attribution to the AI tool
     (`CONTRIBUTING.md` rule 7). Remove any footer your tool adds by default.

   The PR must not go public without its required screenshots (see *Attach
   screenshots* below). With `--attach`, they upload in the create command
   itself. With fork hosting, show the user which files will be pushed, push
   them after they confirm, and put the links in the body before creating the
   PR.

   Show the assembled title and body to the user for confirmation. Write the
   body to `pr-body.md` in the branch's evidence folder (create it with a `meta`
   file as utm-test does; see *Clean up testing evidence* for the path) with
   your file-writing tool or a quoted heredoc (`<<'EOF'`), never a quoted
   `--body`, because the shell would expand backticks and `$` in it. Relative image links
   such as `./before-x.png` then resolve against that folder. Then create:
   ```sh
   gh pr create --repo utmapp/UTM --base main \
     --head "<owner>:<branch>" --title "<title>" --body-file <that file>
   ```
   (In a stack, `--base` is the branch of the PR below; see *One PR with
   several commits, or a stack of PRs*.)
   (Use `<owner>:<branch>` when submitting from a fork; plain `<branch>` when the
   head is on `utmapp/UTM` itself.)

   *No `gh`?* Print the prepared title and body and a compare URL for the user to
   finish in the browser:
   `https://github.com/utmapp/UTM/compare/main...<owner>:<branch>?expand=1`.

6. **Report** the PR URL, then delete the testing evidence (see *Clean up
   testing evidence* below). If the user is attaching screenshots in the
   browser, wait until they confirm that's done, because they're uploading the
   files from that folder.

## Attach screenshots

Use the first of these that works:

1. **`gh --attach`** (needs push access to utmapp/UTM). Check that `gh pr create
   --help` lists `--attach` and that
   `gh api repos/utmapp/UTM --jq .permissions.push` prints `true`. Then pass each
   file to `gh pr create` or `gh pr edit` as `--attach '<file>#<alt text>'`.
   A `![alt](./before-x.png)` reference in the body file is rewritten to point
   at the upload. Uploads are limited to images and video. If some uploads
   fail, `gh` still creates or updates the PR, exits non-zero, and prints the
   PR URL. Never create the PR again. Re-attach the missing files with
   `gh pr edit <number> --repo utmapp/UTM --attach …`, or use option 2 with
   `gh pr edit`.
2. **Host them on your fork** (most contributors push to a fork, so `--attach`
   is refused). Commit the files to a `pr-assets/<branch>` branch with no
   history (or add to it on later updates), push it to the fork, and link the
   images by commit. This needs git 2.42 or later for `worktree add --orphan`.
   Run it as one command:
   ```sh
   branch=$(git rev-parse --abbrev-ref HEAD); fork=<fork-remote>; wt=$(mktemp -d)
   if git show-ref --verify --quiet "refs/heads/pr-assets/$branch"; then
     git worktree add "$wt" "pr-assets/$branch"
   else
     git worktree add --orphan -b "pr-assets/$branch" "$wt"
   fi &&
   cp <evidence files> "$wt"/ && git -C "$wt" add -A &&
   { git -C "$wt" diff --cached --quiet || git -C "$wt" commit -m "Screenshots for $branch"; } &&
   git -C "$wt" push "$fork" "pr-assets/$branch" &&
   echo "base: https://raw.githubusercontent.com/$(gh repo view "$(git remote get-url "$fork")" --json nameWithOwner -q .nameWithOwner)/$(git -C "$wt" rev-parse HEAD)"
   git worktree remove "$wt" 2>/dev/null || rm -rf "$wt"
   ```
   In the body, use `![<alt text>](<base>/<file>)`.
   Linking the commit keeps the images working even if the branch is replaced.
   Leave the branch on the fork while the PR is open, because it hosts the
   images.
3. **Last resort** (no `gh`, or the push fails): use the browser compare-URL
   route in Step 3b.5, or edit the description in the browser, and ask the user
   to drag the files in. `.git` is hidden in Finder, so run `open` on the
   branch's evidence folder to show it to them.

## Clean up testing evidence

`/utm-test` saves evidence in `utm-test-evidence/<branch>` under the main git
dir, so it survives across sessions. Once the PR's Testing section has been written, the evidence isn't
needed, so don't keep it around:

```sh
rm -rf "$(git rev-parse --path-format=absolute --git-common-dir)/utm-test-evidence/$(git rev-parse --abbrev-ref HEAD)"
```

Do this only after a successful create or update. If the workflow is cancelled
or fails, keep the evidence so the next attempt can use it.

## Commit & message policy (applies to every commit this workflow creates)

The critical few, inlined because they must fire at commit time — see
`CONTRIBUTING.md` (Attribution) for the full policy:

- Title: `component: short description`. Body explains **why** and references the
  issue being addressed.
- **Do not add a `Co-authored-by` trailer**, and strip any that a tool added, so that a
  human takes full responsibility for the code. This
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
