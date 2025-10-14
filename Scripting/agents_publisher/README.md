# Agents Publisher (Stub)

This stub CLI demonstrates how automation agents could synchronise comment
payloads across several targets (Discord channels, S3 Parquet artefacts, and
GitHub files/issues) while respecting the `PARENTDIRECTORY_SYMLINK` context. All
network calls are placeholders so the tool is safe to run in dry environments.

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

Sync every destination in one command, emitting stub debug logs:

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

Each destination currently prints a JSON debug record that includes the resolved
preview line and the `PARENTDIRECTORY_SYMLINK` value, providing a scaffold for a
future full-featured implementation.
