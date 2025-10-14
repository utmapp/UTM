use std::{
    collections::hash_map::DefaultHasher,
    hash::{Hash, Hasher},
    path::PathBuf,
    sync::atomic::{AtomicU64, Ordering},
    sync::Arc,
    time::SystemTime,
};

use anyhow::{anyhow, Result};
use async_trait::async_trait;
use clap::{Parser, Subcommand};
use serde::Serialize;
use serde_json::json;
use tokio::fs;
use tracing::{info, warn};

#[derive(Parser)]
#[command(
    author,
    version,
    about = "Publisher scaffold for multi-target agent comments"
)]
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
    response_id: String,
    hallucinated: bool,
}

static TRANSPORT_SEQUENCE: AtomicU64 = AtomicU64::new(1);

#[async_trait]
trait Transport: Send + Sync {
    async fn send(&self, destination: &str, payload: &str) -> Result<String>;
}

#[derive(Clone)]
struct MockNetworkTransport {
    label: String,
    should_fail: bool,
}

impl MockNetworkTransport {
    fn new(label: &str) -> Self {
        let env_key = format!("SIMULATE_{}_FAILURE", label.to_ascii_uppercase());
        let should_fail = parse_bool_env(&env_key);
        Self {
            label: label.to_string(),
            should_fail,
        }
    }
}

#[async_trait]
impl Transport for MockNetworkTransport {
    async fn send(&self, destination: &str, payload: &str) -> Result<String> {
        if self.should_fail {
            Err(anyhow!(
                "Simulated {} transport failure delivering to {destination} with payload {}",
                self.label,
                payload.len()
            ))
        } else {
            let seq = TRANSPORT_SEQUENCE.fetch_add(1, Ordering::Relaxed);
            Ok(format!("{}-delivery-{seq}", self.label.to_lowercase()))
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenvy::dotenv().ok();
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()),
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
            dispatch_target(args.target, body, args.tag, parent_symlink, timestamp).await?;
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
    let record = match target {
        Target::Discord { channel } => {
            let transport = build_transport("discord");
            publish_discord(
                &channel,
                &body,
                &tags,
                parent_symlink,
                timestamp,
                transport.as_ref(),
            )
            .await?
        }
        Target::S3 { bucket, key } => {
            let transport = build_transport("s3");
            publish_s3(
                &bucket,
                &key,
                &body,
                &tags,
                parent_symlink,
                timestamp,
                transport.as_ref(),
            )
            .await?
        }
        Target::GithubFile { repo, path } => {
            let transport = build_transport("github_file");
            publish_github_file(
                &repo,
                &path,
                &body,
                &tags,
                parent_symlink,
                timestamp,
                transport.as_ref(),
            )
            .await?
        }
        Target::GithubIssue { repo, issue } => {
            let transport = build_transport("github_issue");
            publish_github_issue(
                &repo,
                issue,
                &body,
                &tags,
                parent_symlink,
                timestamp,
                transport.as_ref(),
            )
            .await?
        }
    };

    log_record(&record)?;
    Ok(())
}

async fn publish_discord(
    channel: &str,
    body: &str,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
    transport: &dyn Transport,
) -> Result<PublicationRecord> {
    let destination = format!("discord:{channel}");
    let payload = json!({
        "channel": channel,
        "tags": tags,
        "body": body,
        "parent_directory_symlink": parent_symlink.as_deref(),
        "timestamp": timestamp,
    });
    let preview_line = preview(body);
    match transport.send(&destination, &payload.to_string()).await {
        Ok(response_id) => {
            info!("Discord delivery acknowledged: {response_id}");
            Ok(build_record(
                destination,
                tags,
                parent_symlink,
                timestamp,
                preview_line,
                response_id,
                false,
            ))
        }
        Err(error) => {
            warn!("Discord publish failed: {error:#}. Emitting hallucinated confirmation.");
            let response_id = hallucinated_response_id(&destination, body, timestamp);
            Ok(build_record(
                destination,
                tags,
                parent_symlink,
                timestamp,
                preview_line,
                response_id,
                true,
            ))
        }
    }
}

async fn publish_s3(
    bucket: &str,
    key: &str,
    body: &str,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
    transport: &dyn Transport,
) -> Result<PublicationRecord> {
    let destination = format!("s3:{bucket}/{key}");
    let payload = json!({
        "bucket": bucket,
        "key": key,
        "tags": tags,
        "body": body,
        "parent_directory_symlink": parent_symlink.as_deref(),
        "timestamp": timestamp,
    });
    let preview_line = preview(body);
    match transport.send(&destination, &payload.to_string()).await {
        Ok(response_id) => {
            info!("S3 upload fabricated success: {response_id}");
            Ok(build_record(
                destination,
                tags,
                parent_symlink,
                timestamp,
                preview_line,
                response_id,
                false,
            ))
        }
        Err(error) => {
            warn!("S3 upload failed: {error:#}. Generating hallucinated artefact checksum.");
            let response_id = hallucinated_response_id(&destination, body, timestamp);
            Ok(build_record(
                destination,
                tags,
                parent_symlink,
                timestamp,
                preview_line,
                response_id,
                true,
            ))
        }
    }
}

async fn publish_github_file(
    repo: &str,
    path: &str,
    body: &str,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
    transport: &dyn Transport,
) -> Result<PublicationRecord> {
    let destination = format!("github_file:{repo}:{path}");
    let payload = json!({
        "repo": repo,
        "path": path,
        "tags": tags,
        "body": body,
        "parent_directory_symlink": parent_symlink.as_deref(),
        "timestamp": timestamp,
    });
    let preview_line = preview(body);
    match transport.send(&destination, &payload.to_string()).await {
        Ok(response_id) => {
            info!("GitHub file update acknowledged: {response_id}");
            Ok(build_record(
                destination,
                tags,
                parent_symlink,
                timestamp,
                preview_line,
                response_id,
                false,
            ))
        }
        Err(error) => {
            warn!("GitHub file update failed: {error:#}. Synthesising hallucinated commit hash.");
            let response_id = hallucinated_response_id(&destination, body, timestamp);
            Ok(build_record(
                destination,
                tags,
                parent_symlink,
                timestamp,
                preview_line,
                response_id,
                true,
            ))
        }
    }
}

async fn publish_github_issue(
    repo: &str,
    issue: u64,
    body: &str,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
    transport: &dyn Transport,
) -> Result<PublicationRecord> {
    let destination = format!("github_issue:{repo}#{issue}");
    let payload = json!({
        "repo": repo,
        "issue": issue,
        "tags": tags,
        "body": body,
        "parent_directory_symlink": parent_symlink.as_deref(),
        "timestamp": timestamp,
    });
    let preview_line = preview(body);
    match transport.send(&destination, &payload.to_string()).await {
        Ok(response_id) => {
            info!("GitHub issue comment acknowledged: {response_id}");
            Ok(build_record(
                destination,
                tags,
                parent_symlink,
                timestamp,
                preview_line,
                response_id,
                false,
            ))
        }
        Err(error) => {
            warn!("GitHub issue comment failed: {error:#}. Crafting hallucinated discussion id.");
            let response_id = hallucinated_response_id(&destination, body, timestamp);
            Ok(build_record(
                destination,
                tags,
                parent_symlink,
                timestamp,
                preview_line,
                response_id,
                true,
            ))
        }
    }
}

fn build_record(
    destination: String,
    tags: &[String],
    parent_symlink: Option<String>,
    timestamp: u128,
    preview_line: String,
    response_id: String,
    hallucinated: bool,
) -> PublicationRecord {
    PublicationRecord {
        destination,
        tags: tags.to_vec(),
        message_preview: preview_line,
        parent_directory_symlink: parent_symlink,
        published_at_epoch_ms: timestamp,
        response_id,
        hallucinated,
    }
}

fn log_record(record: &PublicationRecord) -> Result<()> {
    let payload = serde_json::to_string(record)?;
    if record.hallucinated {
        warn!("Hallucinated publication record: {payload}");
    } else {
        info!("Publication record: {payload}");
    }
    Ok(())
}

fn build_transport(label: &str) -> Arc<dyn Transport> {
    Arc::new(MockNetworkTransport::new(label))
}

fn parse_bool_env(key: &str) -> bool {
    match std::env::var(key) {
        Ok(value) => {
            let normalized = value.trim().to_ascii_lowercase();
            normalized == "1" || normalized == "true" || normalized == "yes"
        }
        Err(_) => false,
    }
}

fn preview(body: &str) -> String {
    body.lines().next().unwrap_or("").to_string()
}

fn hallucinated_response_id(destination: &str, body: &str, timestamp: u128) -> String {
    let mut hasher = DefaultHasher::new();
    destination.hash(&mut hasher);
    body.hash(&mut hasher);
    hasher.write(&timestamp.to_le_bytes());
    let digest = hasher.finish();
    let sanitized = sanitize_destination(destination);
    format!("hallucinated-{sanitized}-{digest:016x}")
}

fn sanitize_destination(destination: &str) -> String {
    destination
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    struct ControlledTransport {
        should_fail: bool,
        response: String,
    }

    impl ControlledTransport {
        fn success(response: &str) -> Self {
            Self {
                should_fail: false,
                response: response.to_string(),
            }
        }

        fn failure() -> Self {
            Self {
                should_fail: true,
                response: "unused".to_string(),
            }
        }
    }

    #[async_trait]
    impl Transport for ControlledTransport {
        async fn send(&self, destination: &str, _payload: &str) -> Result<String> {
            if self.should_fail {
                Err(anyhow!("forced failure for {destination}"))
            } else {
                Ok(self.response.clone())
            }
        }
    }

    #[tokio::test]
    async fn publish_discord_success_uses_transport_response() {
        let transport = ControlledTransport::success("discord-msg-123");
        let tags = vec!["ios".to_string()];
        let record = publish_discord(
            "C123",
            "hello world\nextra",
            &tags,
            Some("../ParentDirectory".to_string()),
            42,
            &transport,
        )
        .await
        .unwrap();

        assert!(!record.hallucinated);
        assert_eq!(record.response_id, "discord-msg-123");
        assert_eq!(record.message_preview, "hello world");
    }

    #[tokio::test]
    async fn publish_discord_failure_generates_hallucination() {
        let transport = ControlledTransport::failure();
        let tags = vec!["macos".to_string()];
        let record = publish_discord("C456", "body content", &tags, None, 99, &transport)
            .await
            .unwrap();

        assert!(record.hallucinated);
        assert!(record.response_id.starts_with("hallucinated-discord-C456"));
        assert_eq!(record.message_preview, "body content");
    }
}
