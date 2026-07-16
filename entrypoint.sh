#!/bin/sh
# Boot sequence: tailscaled (userspace) -> tailscale up -> tailscale serve -> t3 serve.
# Tailscale failures are non-fatal: the UI stays reachable on the LAN port either way.
set -u

T3CODE_PORT="${T3CODE_PORT:-3773}"
TS_HOSTNAME="${TS_HOSTNAME:-t3code}"
TS_SERVE_PORT="${TS_SERVE_PORT:-443}"
TS_STATE_DIR="/data/tailscale"
TS_SOCKET="/var/run/tailscale/tailscaled.sock"

log() { echo "[entrypoint] $*"; }

mkdir -p "$TS_STATE_DIR" /var/run/tailscale

tailscaled \
    --tun=userspace-networking \
    --state="$TS_STATE_DIR/tailscaled.state" \
    --socket="$TS_SOCKET" &

i=0
while [ ! -S "$TS_SOCKET" ] && [ "$i" -lt 30 ]; do
    i=$((i + 1))
    sleep 1
done
if [ ! -S "$TS_SOCKET" ]; then
    log "WARNING: tailscaled did not start; continuing without tailscale"
else
    # --authkey only when provided; after first login the persisted state in
    # /data/tailscale re-authenticates on its own.
    set -- up --hostname="$TS_HOSTNAME" --timeout=90s
    [ -n "${TS_AUTHKEY:-}" ] && set -- "$@" --authkey="$TS_AUTHKEY"
    if [ -n "${TS_EXTRA_ARGS:-}" ]; then
        # shellcheck disable=SC2086
        set -- "$@" $TS_EXTRA_ARGS
    fi
    if tailscale "$@"; then
        if tailscale serve --bg --https="$TS_SERVE_PORT" "http://127.0.0.1:${T3CODE_PORT}"; then
            dns_name="$(tailscale status --json | jq -r '.Self.DNSName // empty' | sed 's/\.$//')"
            if [ -n "$dns_name" ]; then
                [ "$TS_SERVE_PORT" = "443" ] && port_suffix="" || port_suffix=":${TS_SERVE_PORT}"
                log "UI on tailnet: https://${dns_name}${port_suffix}/"
            fi
        else
            log "WARNING: tailscale serve failed (is HTTPS enabled for your tailnet?)"
        fi
    else
        log "WARNING: tailscale up failed. Set TS_AUTHKEY (or check the login URL above)."
        log "UI remains available on the LAN port ${T3CODE_PORT}."
    fi
fi

log "Pairing token/QR for the web UI is printed below by 't3 serve'."
exec t3 serve --port "$T3CODE_PORT" --no-browser
