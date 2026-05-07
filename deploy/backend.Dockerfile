FROM rust:1.88-bookworm AS build

WORKDIR /app/rust
COPY rust/Cargo.toml rust/Cargo.lock ./
COPY rust/crates ./crates
RUN cargo build --release -p server

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --system --user-group taskwarrior
WORKDIR /app
COPY --from=build /app/rust/target/release/server /usr/local/bin/server
RUN mkdir -p /config /data \
    && chown -R taskwarrior:taskwarrior /app /config /data

USER taskwarrior
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/server"]
CMD ["--config", "/config/backend.toml"]
