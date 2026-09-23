---
name: utm-release
description: Publish a new UTM release on GitHub. Drafts the release notes from the commits and pull requests since the last release, has the user approve them, bumps the version in Build.xcconfig, commits and tags it, pushes, and creates the GitHub release with a discussion in the "Releases" category, which starts the release pipeline. Use this when the user wants to cut, publish, tag, or draft a UTM release or beta, or runs /utm-release.
---

# utm-release

This is the canonical copy. The per-agent entries in `.claude/commands/` and
`.opencode/command/` point here. `$SCRATCH` means your agent's scratch directory,
or `mktemp -d` if you don't have one.

Arguments, both optional and in this order:

1. **Version** `x.y.z`. The default is the next revision after the current
   `MARKETING_VERSION` in `Build.xcconfig` (5.0.5 → 5.0.6).
2. **Prerelease** `yes` or `no`. The default is `yes`.

Read `Documentation/Release.md` first. Its "Release notes" section describes how
the app parses the notes, and how to version and write them. Its "Release notes
template" gives the layout and the footer (from `## Issues` to the end), which
you copy verbatim. This skill doesn't repeat those rules, so apply them.

## Ground rules

- **Nothing leaves the machine until the user approves the notes.** Pushing
  the tag and creating the release start the public pipeline, which signs the
  build and submits it to App Store Connect. It can't be undone cleanly.
- The GitHub secrets and variables are already set up. Don't read, change, or
  check them.
- Commit `Build.xcconfig` only. Leave any other changes in the working tree
  alone.

## Step 1: Preflight

```sh
git fetch origin --tags
git status --short
git rev-parse --abbrev-ref HEAD            # must be main
git rev-list --left-right --count HEAD...origin/main   # must be 0 0
grep -E '^(MARKETING_VERSION|CURRENT_PROJECT_VERSION)' Build.xcconfig
gh release list -R utmapp/UTM -L 10
```

- Stop and ask if you're not on `main`, if `main` differs from `origin/main`, or
  if `Build.xcconfig` has uncommitted changes. Other dirty files are fine.
- If `gh` isn't authenticated, ask the user to run `gh auth login`.
- The **previous release** is the newest entry in `gh release list`. Its tag
  should match the current `MARKETING_VERSION`. If it doesn't, tell the user
  before you continue.
- Work out the new version and check that it is greater than the previous one.
  If tag `vx.y.z` already exists, locally or on GitHub, stop. The user probably
  wants a re-release. Point them to "Re-release" in `Release.md` and ask how to
  proceed.
- The new build number is the current `CURRENT_PROJECT_VERSION` + 1.

## Step 2: Start the notes

- **Revision** (same `x.y` as the previous release, z > 0): start from the
  previous release's full notes:
  `gh release view <prev-tag> -R utmapp/UTM --json body -q .body | tr -d '\r'`.
  Keep every section, including all the older `## Changes` sections.
- **New minor or major version**: start from the template in `Release.md`.
  Carry nothing over from the previous series.

Either way, replace the footer with the one in `Release.md`, so the release uses
the current template.

## Step 3: Collect the changes

List everything that landed since the previous release:

```sh
git log --first-parent --reverse --format='%H %an <%ae>%n  %s' <prev-tag>..origin/main
```

Each entry is one of these:

- **A merge commit** (`Merge pull request #N from owner/branch`): one PR.
- **A squash merge** (subject ends in `(#N)`): one PR.
- **A direct commit to `main`**: its own change.

For each PR, fetch its details:

```sh
gh pr view N -R utmapp/UTM --json title,body,author,commits,files,closingIssuesReferences
gh api repos/utmapp/UTM/pulls/N --jq '.user.login + " " + .author_association'
```

For a direct commit, read `git show --stat <sha>`, and get the author's GitHub
login with `gh api repos/utmapp/UTM/commits/<sha> --jq .author.login`.

Then write one bullet per PR or direct commit, in the format that `Release.md`
gives. Work out each part from the code and the discussion, not only from the
title:

- **What changed.** Describe what users see, and start with a verb (Fixed,
  Added, Support, …). If several PRs or commits build one feature, merge them
  into one bullet.
- **Platform.** Judge from the files touched and from `#if os(...)`,
  `WITH_QEMU_TCI`, `@available`, or `#available` checks. The code in
  `Platform/macOS/`, the Apple Virtualization backend (`UTMAppleVirtualMachine`
  and `Configuration/UTMAppleConfiguration*`), `QEMUHelper`, `QEMULauncher`, and
  `utmctl` is macOS-only. If a change only applies from some OS version, add the
  version: `(macOS 26)`. Use only prefixes that the table in `Release.md` accepts.
- **Component.** Use the same names as earlier notes (the list in `Release.md`,
  and whatever the previous notes used). Translations are always
  `Localization:`, with each language named in English (`German`, not `de`).
  Work the language out from the `.lproj` folders that the change touches (for
  example `Platform/de.lproj` is German, and `zh-HK` plus `zh-Hans` is
  `Chinese (Hong Kong, Simplified)`).
- **Issue.** If the change fixes a bug or resolves a request that has an issue,
  add `(#N)`. Find it in `closingIssuesReferences` or a `Fixes`, `Resolves`, or
  `Closes #N` line in the PR body or the commit messages. Don't cite the PR
  number itself.
- **Credit.** If `author_association` isn't `OWNER` or `MEMBER`, add
  `(thanks @login)`. Do the same for a direct commit by someone other than a
  maintainer. Don't credit bots.
- **Leave out** changes that users can't see: docs, CI, agent skills, tests,
  refactors, and build scripts that don't change what ships. Keep build fixes
  that do change the shipped app. For example, a dependency link fix that makes
  UTM run on older macOS is user-visible. Keep a list of what you left out, to
  show the user.

Put the new bullets in `## Changes (vx.y.z)`, directly above the previous
`## Changes` section. Sort them into the groups that `Release.md` describes:
changes for every platform first, then each platform's own changes, and within
each of those, every bullet for the same component next to the others. Check the
order again after the user's edits in Step 5. Leave the older sections in the
order they were published, but offer to sort any that aren't sorted yet.

## Step 4: Highlights and notes

- **Highlights.** Review the list with the whole release, or series, in mind.
  Add a highlight only for a major feature or change, or a theme that several
  changes share. Write for a general audience, with marketing terms rather than
  technical ones. On a revision, keep the earlier highlights, but you may reword
  or merge them when a new change extends one. If nothing is worth a
  highlight, don't invent one. Tell the user instead, because the first section
  is what the app shows up front.
- **Notes and Known Issues.** Keep the carried-over entries, but flag any that
  are now stale, such as a requirement that was reverted or a known issue that
  this release fixes. Suggest removing them rather than removing them yourself.
  Propose new notes when a change needs action from users (reinstall a driver,
  new minimum OS, changed defaults).

## Step 5: Get the notes approved

Write the notes to `$SCRATCH/release-notes-vx.y.z.md`. Show the user:

- the full notes,
- the title (`vx.y.z (Beta)` for a prerelease, otherwise `vx.y.z`), the version,
  the build number, and whether it's a prerelease,
- the commits and PRs you left out, and why,
- anything you weren't sure about: platform, issue, credit, or stale notes.

Then **stop and wait**. The user may add notes or highlights, or edit the
changelog. Apply their edits to the file and show the result again. Repeat until
they approve this exact text. If they change the version or the prerelease
setting, go back to Step 1.

## Step 6: Bump, commit, tag, push

Once the user has approved:

1. In `Build.xcconfig`, set `MARKETING_VERSION = x.y.z` and
   `CURRENT_PROJECT_VERSION` to the new build number. Change nothing else.
2. Commit only that file. The title is exactly `project: bumped version`, and it
   carries the AI-attribution trailer that `AGENTS.md` requires:
   ```sh
   git add Build.xcconfig
   git commit -m "project: bumped version" -m "Assisted-by: AGENT:MODEL"
   ```
   Put your own agent and model in the trailer. Don't add `Co-authored-by` or
   session links, and remove any that your tools add.
3. Tag the commit and push both. Use a lightweight tag, like earlier releases:
   ```sh
   git tag vx.y.z
   git push origin main
   git push origin vx.y.z
   ```
   If the push to `main` is rejected, stop and tell the user. Don't force-push or
   rebase over new commits on `main`. If new commits landed, their changes are
   missing from the notes.

## Step 7: Create the release

```sh
gh release create vx.y.z -R utmapp/UTM --verify-tag \
  --title "vx.y.z (Beta)" --prerelease \
  --notes-file "$SCRATCH/release-notes-vx.y.z.md" \
  --discussion-category "Releases"
```

For a stable release, use `--title "vx.y.z"` and `--latest` instead of
`--prerelease`. Don't create a draft. The pipeline runs on the release's
`created` event, and a published release is what the app downloads its notes
from.

Then check the result, and fix what you can:

```sh
gh release view vx.y.z -R utmapp/UTM --json name,isPrerelease,url
gh api graphql -f query='{repository(owner:"utmapp",name:"UTM"){discussions(first:3,orderBy:{field:CREATED_AT,direction:DESC}){nodes{title url category{name}}}}}'
gh run list -R utmapp/UTM --workflow Build --event release -L 1   # not "build.yml": that filter returns stale runs
```

- The discussion must be titled like the release and be in "Releases".
- A `Build` run titled like the release should have started for the release event.

Report the release URL, the discussion URL, and the pipeline run URL. Don't wait
for the pipeline to finish unless the user asks.
