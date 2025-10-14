# Awesome Actions Publishing Stack

This overview captures how the Awesome GitHub Actions LaTeX artefacts are turned
into a live GitHub Pages site and how conversation transcripts are archived for
future agents.

## Workflow Topology
```
┌────────────────────────────┐      ┌────────────────────────────┐
│ Awesome GitHub Actions CI │      │ Publish Awesome Actions    │
│ (LaTeX/PDF generator)     │      │ Docs (GitHub Actions)      │
└────────────┬──────────────┘      └────────────┬───────────────┘
             │                                   │
             │ writes                             │ packages
             ▼                                   ▼
      docs/awesome-actions-report.pdf     docs/ (HTML, metadata)
             │                                   │
             ├───────────────┐                   │ upload-pages-artifact
             │               │                   │
             ▼               ▼                   ▼
  docs/awesome-actions-report.html    Documentation/conversations/
             │                                   │
             └───────────────────────┬───────────┘
                                     ▼
                           GitHub Pages Deployment
```

The `Publish Awesome Actions Docs` workflow runs on `main` pushes affecting the
documentation or manually via `workflow_dispatch`. It packages `docs/` as a
Pages artefact and deploys via `actions/deploy-pages`.

## Directory Contract
- `docs/index.md`: Markdown landing page rendered by Pages.
- `docs/awesome-actions-report.pdf`: Latest LaTeX output; overwritten by the
  generator workflow.
- `docs/awesome-actions-report.html`: Lightweight viewer embedding the PDF.
- `Documentation/conversations/`: Session summaries with timestamps and branch
  metadata to preserve agent continuity.
- `docs/publish-metadata.txt`: Generated during deployment runs to timestamp the
  publish event.

## Required Automation Steps
1. **Render Artefacts**: Ensure the upstream workflow copies the compiled PDF
   into `docs/awesome-actions-report.pdf` and refreshes the HTML if the schema
   changes.
2. **Archive the Session**: Before finishing a change, store the current
   conversation under `Documentation/conversations/` with clear headings.
3. **Trigger Deployment**: Merge to `main` or use `workflow_dispatch` to push
   the latest bundle to Pages. Verify the site at the URL emitted by the deploy
   job.

## Debugging Tips
- Inspect the generated `docs/publish-metadata.txt` in the workflow artefact to
  confirm the deploy step ran with the expected timestamp.
- Use `actions/github-script` or `gh api` to list the latest Pages deployment if
  stale content appears.
- Keep the placeholder PDF in source control to provide a deterministic preview
  for branches where the LaTeX job has not executed yet.
