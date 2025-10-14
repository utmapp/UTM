FROM rust:1.75 as builder
WORKDIR /app
COPY Cargo.toml Cargo.toml
COPY Cargo.lock Cargo.lock
COPY src src
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY --from=builder /app/target/release/agents_publisher /usr/local/bin/agents_publisher
ENV RUST_LOG=info
ENTRYPOINT ["agents_publisher"]
