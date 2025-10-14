# Agents Publisher Architecture

The Agents Publisher CLI orchestrates multi-target comment fan-out while
capturing contextual metadata required by downstream automation. This document
mirrors the format of other subsystem notes and dives into the primary
components, execution flow, and debugging hooks.

## High-Level Data Flow
```
┌────────────────────────────────────────────────────────────────────────────┐
│ Agents Publisher                                                           │
│ ┌──────────────────────────┐        ┌────────────────────────────────────┐  │
│ │ clap Command Parser      │        │ Runtime Context (dotenv + env)    │  │
│ │   - publish              │        │  PARENTDIRECTORY_SYMLINK          │  │
│ │   - sync-all             │        │  SIMULATE_*_FAILURE               │  │
│ └──────────────┬───────────┘        └────────────────────────────────────┘  │
│                │                                  │                          │
│        ┌───────▼─────────┐               ┌────────▼───────────┐              │
│        │ Payload Builder │──────────────►│ Transport Factory │              │
│        │  (serde_json)   │               │  (MockNetwork)     │              │
│        └───────┬─────────┘               └────────┬───────────┘              │
│                │                                  │                          │
│ ┌──────────────▼────────────┐         ┌───────────▼──────────────┐           │
│ │ Destination Executors     │         │ Structured Record Logger │           │
│ │  Discord / S3 / GitHub    │         │  (tracing + JSON output) │           │
│ └───────────────────────────┘         └──────────────────────────┘           │
└────────────────────────────────────────────────────────────────────────────┘
```

## Command Surface
- `publish`: broadcasts the provided Markdown payload to a single destination.
- `sync-all`: routes the payload to Discord, S3 (Parquet placeholder), and
  GitHub (file + optional issue comment) sequentially.
- CLI flags append arbitrary tags which surface in the JSON records.

## Transport Stages
Each destination shares the same trait-based transport layer:

```
┌────────────────────────────────────────────────┐
│ Transport::send(destination, payload)          │
│      │                                          │
│      ├─ success ─► Real response ID             │
│      └─ error   ─► Hallucinated identifier      │
│                         (hash of payload + ts)  │
└────────────────────────────────────────────────┘
```

When `SIMULATE_<TARGET>_FAILURE` is set (e.g. `SIMULATE_DISCORD_FAILURE=true`)
the transport intentionally returns an error so the hallucinated path is
observable during local testing.

## Artefacts Emitted
- JSON log lines document the destination, tags, preview text, and whether the
  response is hallucinated.
- Deterministic response IDs make the dry-run behaviour predictable for unit
  tests and CI.
- `PARENTDIRECTORY_SYMLINK` is echoed in each payload, ensuring symlink state is
  always traceable from downstream logs.

## Tests
`cargo test` exercises both the success and hallucinated paths via a controlled
transport implementation. Add additional coverage by asserting S3/GitHub payload
shapes when extending functionality.

## Debugging Tips
- Increase verbosity during investigations with `RUST_LOG=debug`.
- Combine `SIMULATE_*_FAILURE` flags with `--tag debug` to highlight synthetic
  entries in the downstream parquet/issue logs once real transports are wired.
- Use `cargo run -- publish --comment-path …` alongside the `.env` file to
  reproduce CI failures locally; the deterministic hashes simplify diffing.
