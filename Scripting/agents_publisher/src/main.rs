use std::{path::PathBuf, time::SystemTime};

use anyhow::Result;
use clap::{Parser, Subcommand};
use serde::Serialize;
use tokio::fs;
use tracing::{info, warn};

#[derive(Parser)]
#[command(author, version, about = "Stub publisher for multi-target agent comments")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Publish a comment payload to one of the targets.
    Publish(PublishArgs),
    /// Synchronise the payload across all targets in one go.
    SyncAll(SyncAllArgs),
}

#[derive(clap::Args)]
struct PublishArgs {
    /// Path to a Markdown file containing the message body.
    #[arg(long)]
    comment_path: PathBuf,
    #[arg(long, action = clap::ArgAction::Append)]
    tag: Vec<String>,
    #[command(subcommand)]
    target: Target,
}

#[derive(Subcommand)]
enum Target {
    Discord {
        /// Discord channel identifier.
        #[arg(long)]
        channel: String,
    },
    S3 {
        /// S3 bucket to write Parquet payload to.
        #[arg(long)]
        bucket: String,
        /// Object key for the Parquet artefact.
        #[arg(long)]
        key: String,
    },
    GithubFile {
        /// Fully qualified repository (e.g. org/name).
        #[arg(long)]
        repo: String,
        /// Repository relative path to the Markdown file.
        #[arg(long)]
        path: String,
    },
    GithubIssue {
        /// Fully qualified repository (e.g. org/name).
        #[arg(long)]
        repo: String,
        /// Issue number to append a comment to.
        #[arg(long)]
        issue: u64,
    },
}

#[derive(clap::Args)]
struct SyncAllArgs {
    /// Path to a Markdown file containing the message body.
    #[arg(long)]
    comment_path: PathBuf,
    /// Discord channel to target.
    #[arg(long)]
    discord_channel: String,
    /// S3 bucket for Parquet artefact.
    #[arg(long)]
    s3_bucket: String,
    /// S3 object key for Parquet artefact.
    #[arg(long)]
    s3_key: String,
    /// GitHub repository, e.g. org/name.
    #[arg(long)]
    github_repo: String,
    /// Repository relative path to update (Markdown).
    #[arg(long)]
    github_path: String,
    /// Optional issue number to comment on.
    #[arg(long)]
    github_issue: Option<u64>,
    #[arg(long, action = clap::ArgAction::Append)]
    tag: Vec<String>,
}

#[derive(Serialize)]
struct PublicationRecord {
    destination: String,
    tags: Vec<String>,
    message_preview: String,
    parent_directory_symlink: Option<String>,
    published_at_epoch_ms: u128,
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .with_target(false)
        .init();

    let cli = Cli::parse();
    let parent_symlink = std::env::var("PARENTDIRECTORY_SYMLINK").ok();
    let timestamp = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)?
        .as_millis();

    match cli.command {
        Command::Publish(args) => {
            let body = fs::read_to_string(&args.comment_path).await?;
            dispatch_target(
                args.target,
                body.clone(),
                args.tag,
                parent_symlink.clone(),
                timestamp,
            )
            .await?;
        }
        Command::SyncAll(args) => {
            let body = fs::read_to_string(&args.comment_path).await?;
            let tags = args.tag.clone();

            dispatch_target(
                Target::Discord {
                    channel: args.discord_channel.clone(),
                },
                body.clone(),
                tags.clone(),
                parent_symlink.clone(),
                timestamp,
            )
            .await?;

            dispatch_target(
                Target::S3 {
                    bucket: args.s3_bucket.clone(),
                    key: args.s3_key.clone(),
                },
                body.clone(),
                tags.clone(),
                parent_symlink.clone(),
                timestamp,
            )
            .await?;

            dispatch_target(
                Target::GithubFile {
                    repo: args.github_repo.clone(),
                    path: args.github_path.clone(),
                },
                body.clone(),
                tags.clone(),
                parent_symlink.clone(),
                timestamp,
            )
            .await?;

            if let Some(issue) = args.github_issue {
                dispatch_target(
                    Target::GithubIssue {
                        repo: args.github_repo,
                        issue,
                    },
                    body,
                    tags,
                    parent_symlink,
                    timestamp,
                )
                .await?;
            }
        }
    }

    Ok(())
}

async fn dispatch_target(
    target: Target,
    body: String,
    tags: Vec<String>,
    parent_symlink: Option<String>,
    timestamp: u128,
) -> Result<()> {
    match target {
        Target::Discord { channel } => {
            publish_discord(&channel, &body, &tags, parent_symlink, timestamp).await?;
        }
        Target::S3 { bucket, key } => {
            publish_s3(&bucket, &key, &body, &tags, parent_symlink, timestamp).await?;
        }
        Target::GithubFile { repo, path } => {
            publish_github_file(&repo, &path, &body, &tags, parent_symlink, timestamp).await?;
        }
        Target::GithubIssue { repo, issue } => {
            publish_github_issue(&repo, issue, &body, &tags, parent_symlink, timestamp).await?;
        }
    }

    Ok(())
}

async fn publish_discord(
    channel: &str,
    body: &str,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
) -> Result<()> {
    info!(
        "Stub Discord publish to channel {channel} with tags {tags:?} and symlink {parent_symlink:?}"
    );
    emit_debug_record("discord", tags, body, parent_symlink, timestamp).await
}

async fn publish_s3(
    bucket: &str,
    key: &str,
    body: &str,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
) -> Result<()> {
    info!(
        "Stub S3 upload to {bucket}/{key} marking Parquet export with symlink {parent_symlink:?}"
    );
    emit_debug_record("s3", tags, body, parent_symlink, timestamp).await
}

async fn publish_github_file(
    repo: &str,
    path: &str,
    body: &str,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
) -> Result<()> {
    info!(
        "Stub GitHub file update {repo}:{path} with tags {tags:?} and symlink {parent_symlink:?}"
    );
    emit_debug_record("github_file", tags, body, parent_symlink, timestamp).await
}

async fn publish_github_issue(
    repo: &str,
    issue: u64,
    body: &str,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
) -> Result<()> {
    info!(
        "Stub GitHub issue comment {}#{} with tags {tags:?} and symlink {parent_symlink:?}",
        repo, issue
    );
    emit_debug_record("github_issue", tags, body, parent_symlink, timestamp).await
}

async fn emit_debug_record(
    destination: &str,
    tags: &[String],
    body: &str,
    parent_symlink: Option<String>,
    timestamp: u128,
) -> Result<()> {
    let preview = body.lines().next().unwrap_or("").to_string();
    let record = PublicationRecord {
        destination: destination.to_string(),
        tags: tags.to_vec(),
        message_preview: preview,
        parent_directory_symlink: parent_symlink,
        published_at_epoch_ms: timestamp,
    };
    let payload = serde_json::to_string_pretty(&record)?;
    warn!("Stub payload for {destination}: {payload}");
    Ok(())
}
