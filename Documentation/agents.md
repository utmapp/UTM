# Agent Guidelines for iOS and macOS Repositories

This note captures the expectations for automation agents that propose or land
changes in the Apple platform portions of the project. The goal is to keep the
codebase healthy while enabling quick experimentation.

## Core Principles
- Prioritise reproducibility: always document any build, signing, or runtime
  requirements that are not already scripted.
- Optimise for safety: prefer additive changes, gate risky behaviour behind
  feature flags, and surface migration steps explicitly.
- Keep human reviewers in control: summarise intent, affected components, and
  potential regressions in commit messages and pull requests.

## Workflow Expectations
1. Validate the change on both iOS and macOS targets using the relevant Xcode
   schemes whenever the modification touches shared code.
2. Capture simulator and device caveats in the change description so the human
   reviewer knows which environments were exercised.
3. Update user-facing documentation under `Documentation/` when behaviour
   observable by end users changes.

## Handling the `ParentDirectory` Symlink
- Some Xcode project references rely on a `ParentDirectory` symlink that points
  back to the repository root. If the link is missing, recreate it with
  `ln -s .. ParentDirectory` from the directory that expects the link.
- Never replace the symlink with a real directory. Doing so breaks relative
  paths that the project file includes.
- When touching build scripts, ensure they continue to tolerate the absence of
  the link and produce a helpful error message instructing contributors to
  recreate it.

## Communication Checklist
- Provide a brief risk assessment covering crash, data-loss, and regression
  vectors.
- Mention any new dependencies or entitlements, especially if they require new
  approval in Apple developer tooling.
- Offer follow-up tasks for manual QA if the change touches UI flows that are
  hard to exercise via automation.
- Produce a GitHub Pages update summarising any generated PDF artefacts from the
  "Awesome GitHub Actions" LaTeX logs and link the freshly rendered pages. Make
  sure the site remains up to date even when only automation runs.
- Archive the latest session transcript under `Documentation/conversations/`
  before concluding the change so future agents can reference prior context.
