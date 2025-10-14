# Running the Awesome Actions Workflow Locally

This guide shows how to execute the `Awesome GitHub Actions Report` workflow on
your machine using either a self-hosted Actions runner or the `act` simulator.

## Option A: Self-hosted GitHub Actions Runner
1. **Download the runner bundle**
   ```bash
   mkdir -p ~/actions-runner && cd ~/actions-runner
   curl -o actions-runner-osx-x64-<ver>.tar.gz -L https://github.com/actions/runner/releases/download/v<ver>/actions-runner-osx-x64-<ver>.tar.gz
   tar xzf actions-runner-osx-x64-<ver>.tar.gz
   ```
2. **Configure against this repository**
   ```bash
   ./config.sh \
     --url https://github.com/realagiorganization/UTM \
     --token <REGISTRATION_TOKEN> \
     --name local-awesome-runner \
     --work _work
   ```
   The registration token is generated via GitHub → Settings → Actions →
   Runners → New self-hosted runner.
3. **Launch the runner**
   ```bash
   ./run.sh
   ```
4. **Dispatch the workflow**
   ```bash
   gh workflow run awesome-actions.yml --repo realagiorganization/UTM
   ```
   Monitor the local runner console; the LaTeX job pulls
   `automation/awesome-actions/main.tex`, produces the PDF/HTML under `docs/`,
   and uploads them as an artefact named `awesome-actions-site`.

## Option B: Simulate with `act`
1. **Install `act`** (with Docker running)
   ```bash
   brew install act
   ```
2. **Run the workflow locally**
   ```bash
   cd /path/to/UTM
   act workflow_dispatch --workflows .github/workflows/awesome-actions.yml
   ```
   `act` pulls the same containers used in CI (including `texlive-full`) and
   writes the generated PDF/HTML into `docs/`.
3. **Inspect outputs**
   ```bash
   open docs/awesome-actions-report.pdf
   open docs/awesome-actions-report.html
   ```

## Notes
- Large TeX images: the `latex-action` container is heavy (several GB). Cache it
  locally when possible.
- Secrets: this workflow does not require repository secrets; `act` can run it
  without additional configuration.
- Resetting artefacts: remove `docs/awesome-actions-report.*` before rerunning if
  you want a clean diff in Git.
