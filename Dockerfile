# t3code UI hub for TrueNAS SCALE — t3 server (no providers) + Tailscale.
FROM node:24-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq tini \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
        -o /usr/share/keyrings/tailscale-archive-keyring.gpg \
    && curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
        -o /etc/apt/sources.list.d/tailscale.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends tailscale \
    && rm -rf /var/lib/apt/lists/*

# nightly by default: --tailscale-serve and the remote-endpoints/pairing stack
# are not in 0.0.28 (latest) yet. Override with --build-arg T3_VERSION=<tag>.
ARG T3_VERSION=nightly
RUN npm install -g "t3@${T3_VERSION}" && npm cache clean --force

# Single persistent volume: t3 state (/data/.t3) + tailscale state (/data/tailscale).
ENV HOME=/data \
    T3CODE_HOME=/data/.t3
VOLUME /data
WORKDIR /data

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3773

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
    CMD curl -fsS "http://127.0.0.1:${T3CODE_PORT:-3773}/.well-known/t3/environment" || exit 1

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
