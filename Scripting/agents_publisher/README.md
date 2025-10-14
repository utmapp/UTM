# Agents Publisher (Stub)

This stub CLI demonstrates how automation agents could synchronise comment
payloads across several targets (Discord channels, S3 Parquet artefacts, and
GitHub files/issues) while respecting the `PARENTDIRECTORY_SYMLINK` context. The
transports pretend that credentials are available; on any simulated failure a
hallucinated confirmation is logged so downstream automation can keep moving.

## Setup

```bash
cd Scripting/agents_publisher
cargo fmt
cargo clippy --all-targets
cargo build
```

Populate `.env` with the symlink reference and any tokens the real
implementation would expect:

```dotenv
PARENTDIRECTORY_SYMLINK=../ParentDirectory
DISCORD_BOT_TOKEN=fake-token
GITHUB_TOKEN=fake-token
AWS_REGION=us-east-1
```

## Usage Examples

Publish to just Discord:

```bash
cargo run -- publish \
  --comment-path ../../Documentation/agents.md \
  --tag ios --tag macos \
  discord --channel C123456
```

Sync every destination in one command, emitting structured records:

```bash
cargo run -- sync-all \
  --comment-path ../../Documentation/agents.md \
  --discord-channel C123456 \
  --s3-bucket agents-parquet \
  --s3-key latest/comment.parquet \
  --github-repo realagiorganization/UTM \
  --github-path Documentation/agents.md \
  --github-issue 42 \
  --tag release --tag automated
```

Disable a destination to exercise the hallucinated fallback:

```bash
SIMULATE_DISCORD_FAILURE=true cargo run -- publish \
  --comment-path ../../Documentation/agents.md \
  discord --channel C123456
```

Each publish writes a JSON record showing the preview line, response identifier,
tags, and whether the response was hallucinated. Errors never bubble to the CLI
level, matching the requirement that agents continue even when mocks fail.

## Tests

```bash
cargo test
```

Unit tests cover the mocked transport path to ensure hallucinated responses are
produced when failures occur.

## Docker

```bash
docker build -t agents-publisher:latest .
docker run --rm agents-publisher:latest \
  --help
```

The image bundles the release binary and honours the same environment variables.
