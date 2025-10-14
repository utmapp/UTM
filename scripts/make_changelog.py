#!/usr/bin/env python3
"""
Generate changelog entries comparing the current branch to the upstream branch.

The script creates a dated entry under changelog/ and prepends the same content to
CHANGELOG.md. The upstream remote/branch can be overridden with the environment
variables UPSTREAM_REMOTE and UPSTREAM_BRANCH.
"""

from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def run_git(cmd: list[str], *, check: bool = True) -> str:
    """Run a git command and return stdout as text."""
    result = subprocess.run(["git", *cmd], check=check, capture_output=True, text=True)
    return result.stdout.strip()


def ensure_remote(remote: str) -> str:
    """Return the remote URL or raise an error if it does not exist."""
    try:
        return run_git(["remote", "get-url", remote])
    except subprocess.CalledProcessError as exc:
        raise SystemExit(
            f"Missing upstream remote '{remote}'. "
            "Set UPSTREAM_REMOTE or add the remote explicitly."
        ) from exc


def fetch_remote(remote: str, branch: str) -> None:
    """Fetch the upstream branch to ensure comparisons are up to date."""
    subprocess.run(["git", "fetch", remote, branch], check=True)


def parse_github_slug(remote_url: str) -> str | None:
    """Extract the GitHub slug (owner/repo) from a remote URL."""
    remote_url = remote_url.strip()
    if remote_url.endswith(".git"):
        remote_url = remote_url[:-4]

    prefixes = ("git@github.com:", "https://github.com/", "git://github.com/")
    for prefix in prefixes:
        if remote_url.startswith(prefix):
            return remote_url[len(prefix) :]

    # gh cli style urls (https://github.com:owner/repo)
    alternate_prefix = "https://github.com:"
    if remote_url.startswith(alternate_prefix):
        return remote_url[len(alternate_prefix) :]

    return None


def collect_commits(base_ref: str) -> list[dict[str, str]]:
    """Return a list of commits unique to the current branch."""
    log_format = "%H%x1f%h%x1f%an%x1f%ad%x1f%s%x1f%b%x1e"
    log_output = run_git(
        ["log", f"{base_ref}..HEAD", f"--pretty=format:{log_format}", "--date=short"],
        check=False,
    )
    commits: list[dict[str, str]] = []
    if not log_output.strip():
        return commits

    for entry in log_output.strip().split("\x1e"):
        if not entry:
            continue
        fields = [field.strip() for field in entry.split("\x1f")]
        if len(fields) < 6:
            continue
        full_sha, short_sha, author, date_str, subject, body = fields[:6]
        body_lines = [line.strip() for line in body.strip().splitlines() if line.strip()]
        summary = body_lines[0] if body_lines else ""
        commits.append(
            {
                "full_sha": full_sha,
                "short_sha": short_sha,
                "author": author,
                "date": date_str,
                "subject": subject.strip(),
                "summary": summary,
            }
        )
    return commits


def build_entry_text(
    branch: str,
    base_ref: str,
    base_sha: str,
    commits: list[dict[str, str]],
    origin_slug: str | None,
) -> str:
    """Create the changelog entry text."""
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    lines = [
        f"## {datetime.now().date().isoformat()} – {branch} vs {base_ref}",
        "",
        f"- Generated: {generated_at}",
        f"- Base commit: `{base_sha}`",
        f"- Compared to: `{base_ref}`",
        "",
    ]

    if not commits:
        lines.append("_No changes found compared to upstream._")
    else:
        for commit in commits:
            url = None
            if origin_slug:
                url = f"https://github.com/{origin_slug}/commit/{commit['full_sha']}"
            link_text = commit["subject"] or commit["short_sha"]
            description = (
                f"[{link_text}]({url})" if url else f"{link_text} ({commit['short_sha']})"
            )
            meta = f"{commit['date']} – {commit['author']} – {commit['short_sha']}"
            lines.append(f"- {description} ({meta})")
            if commit["summary"] and commit["summary"] != commit["subject"]:
                lines.append(f"  - {commit['summary']}")

    lines.append("")
    return "\n".join(lines)


def write_entry_files(entry_text: str, branch: str) -> None:
    """Persist the entry to changelog/<file>.md and prepend it to CHANGELOG.md."""
    changelog_dir = Path("changelog")
    changelog_dir.mkdir(exist_ok=True)
    dated_name = f"{datetime.now().date().isoformat()}-{branch}.md"
    entry_path = changelog_dir / dated_name
    entry_path.write_text("# Changelog Entry\n\n" + entry_text, encoding="utf-8")

    overall_path = Path("CHANGELOG.md")
    header = "# Changelog\n\n"
    if overall_path.exists():
        existing = overall_path.read_text(encoding="utf-8")
        if existing.startswith("# Changelog"):
            remainder = existing[len("# Changelog") :].lstrip("\n")
            new_content = header + entry_text + remainder
        else:
            new_content = header + entry_text + existing
    else:
        new_content = header + entry_text
    overall_path.write_text(new_content, encoding="utf-8")


def main() -> None:
    upstream_remote = os.environ.get("UPSTREAM_REMOTE", "upstream")
    upstream_branch = os.environ.get("UPSTREAM_BRANCH", "main")

    ensure_remote(upstream_remote)
    fetch_remote(upstream_remote, upstream_branch)

    branch = run_git(["rev-parse", "--abbrev-ref", "HEAD"])
    base_ref = f"{upstream_remote}/{upstream_branch}"
    base_sha = run_git(["rev-parse", base_ref])

    origin_url = run_git(["remote", "get-url", "origin"])
    origin_slug = parse_github_slug(origin_url)

    commits = collect_commits(base_ref)
    entry_text = build_entry_text(branch, base_ref, base_sha, commits, origin_slug)
    write_entry_files(entry_text, branch)

    print(f"Changelog entry generated with {len(commits)} commit(s).")
    print("Per-entry file and CHANGELOG.md have been updated.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        sys.exit(error.returncode)
