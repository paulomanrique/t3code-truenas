# t3code-truenas

Docker image that runs [T3 Code](https://github.com/pingdotgg/t3code) as an
always-on **UI hub** on TrueNAS SCALE, exposed over your
[Tailscale](https://tailscale.com) tailnet.

The container runs the `t3` server with **no coding-agent CLIs installed**: its
job is to serve the T3 Code web interface. From that UI you pair with and
control t3code servers running on your actual dev machines (the browser
connects to each backend directly — the hub never proxies traffic).

```
phone/laptop ──HTTPS (tailnet)──> t3code hub (TrueNAS)   ← serves the UI
     │
     └──wss (direct)──> t3 serve on dev machine A, B, C  ← agents run here
```

Tailscale runs inside the container in userspace mode, so **no TUN device, no
NET_ADMIN** — it deploys as an unprivileged TrueNAS Custom App.

## Setup

### 1. Create a Tailscale auth key

Tailscale admin console → **Settings → Keys → Generate auth key**.
Recommended: **Reusable**, not ephemeral, optionally tagged (e.g. `tag:nas`,
then set `TS_EXTRA_ARGS=--advertise-tags=tag:nas`). The key is only used on
first boot; after that the login state persists in the `/data` volume.

### 2. Install on TrueNAS SCALE (24.10+)

**Option A — Install via YAML:** Apps → Discover Apps → ⋮ → *Install via YAML*,
paste [`compose.example.yaml`](compose.example.yaml) and fill in `TS_AUTHKEY`
and the host path for `/data`.

**Option B — Custom App form:**

| Field | Value |
|---|---|
| Image | `ghcr.io/paulomanrique/t3code-truenas:latest` |
| Environment | `TS_AUTHKEY` = your key (plus optional vars below) |
| Port | 3773 → 3773 (TCP, optional — LAN access) |
| Storage | host path (e.g. `/mnt/pool/apps/t3code`) → `/data` |

### 3. First access

Open the app logs in TrueNAS. You'll see:

- `UI on tailnet: https://t3code.<your-tailnet>.ts.net/` — the interface URL
  (requires [HTTPS certificates](https://tailscale.com/kb/1153/enabling-https)
  enabled for your tailnet), and
- the **one-time pairing token / QR code** printed by `t3 serve` — the web UI
  requires it because the server listens on a non-loopback interface.

Open the URL from any device on your tailnet and pair with the token.

### 4. Connect your dev machines

On each machine where agents should actually run (Codex/Claude/Cursor/
OpenCode installed and logged in):

```sh
npx t3@nightly serve --tailscale-serve
```

Then, in the hub UI: **Settings → Connections** → add the printed
host + pairing token.

> **HTTPS required:** the hub page is served over HTTPS, so browsers will only
> connect to `https`/`wss` backends (mixed content). `--tailscale-serve` on
> each dev machine handles that; plain `http://192.168.x.x:3773` backends will
> be blocked by the browser.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `TS_AUTHKEY` | — | Tailscale auth key (first boot only) |
| `TS_HOSTNAME` | `t3code` | Device name on the tailnet |
| `TS_EXTRA_ARGS` | — | Extra flags for `tailscale up` |
| `T3CODE_PORT` | `3773` | HTTP/WebSocket port of the t3 server |
| `TS_SERVE_PORT` | `443` | HTTPS port for `tailscale serve` |

## Device management

Revoke or inspect paired UI devices:

```sh
docker exec -it <container> t3 auth
```

## Notes

- The image installs `t3@nightly` by default: `--tailscale-serve` and the
  multi-backend pairing stack are not in the `latest` npm release yet. Pin a
  different version with `--build-arg T3_VERSION=<tag>`.
- T3 Code is in early development (0.0.x) — expect breaking changes. The CI
  workflow polls npm every 6 hours and publishes a new image whenever a new
  `t3@nightly` appears, tagged both `:latest` and with the exact t3 version
  (e.g. `:0.0.29-nightly.20260716.825`). If a nightly breaks, point the app at
  the last good version tag.
