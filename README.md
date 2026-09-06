# Deploy and Host

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/pufferpanel)

PufferPanel — open-source game server management panel. Manage Minecraft, CS2, Valheim, and 50+ other game servers from a clean web UI with per-server users, file manager, console, stats, and SFTP access.

## Source Repository

[https://github.com/INAPP-Mobile/pufferpanel](https://github.com/INAPP-Mobile/pufferpanel)

## System Requirements

- **Disk:** 10GB+ dedicated volume (panel DB + per-server game files)
- **Memory:** 512 MB RAM minimum for the panel (game servers need their own headroom)
- **Network:** HTTPS for the panel UI; optional TCP 5657 proxy for SFTP

## About Hosting

This template deploys a single service running PufferPanel v3 (panel + daemon in one process) with SQLite at `/var/lib/pufferpanel/database.db` on a persistent Railway volume — no companion database needed. The admin account is created automatically on first boot; log in with the credentials from your Variables tab.

Because Railway doesn't grant `CAP_SYS_ADMIN`, game servers run as **direct host processes** under the panel (upstream `disableUnshare` mode) rather than in Docker sandboxes. The "docker" environment option is intentionally disabled; choose "host"-style server definitions when adding servers. Game servers also need their listen ports reachable from players. Railway exposes only HTTP/HTTPS domains and TCP proxies to the public internet — **inbound UDP is not supported** (enabling static outbound IPs does not change this; those addresses are egress-only). TCP-native games (e.g., Minecraft Java, Terraria) work via Railway TCP proxies; UDP-based games (7 Days to Die, Valheim, CS2) are only joinable from the private network, not by external players. This panel is therefore best suited for panel management, file/console/SFTP administration, and TCP-reachable game servers.

**Playing UDP games externally (optional playit.gg tunnel):** set the `PLAYIT_SECRET` variable to your agent secret from [playit.gg](https://playit.gg) and the container automatically starts the playit agent, which opens an *outbound* tunnel — no inbound ports needed. In the playit dashboard, create port mappings for your game servers (e.g., `127.0.0.1:2456` UDP for Valheim, `127.0.0.1:26900` UDP for 7DTD, `127.0.0.1:7777` UDP for ARK) and share the generated `*.playit.gg` address with players instead of the Railway domain. Leave `PLAYIT_SECRET` empty if you only host TCP games.

> **Note:** Railway's HTTP proxy handles SSL termination for the panel UI. The SFTP daemon (port 5657) requires a Railway TCP proxy if you want external SFTP access.

**First-run setup: none.** The entrypoint runs the database migration and creates the admin account automatically:

- **Username:** `admin` (default)
- **Password:** auto-generated via `${{secret(16)}}` — copy it from the service **Variables** tab after deploy

Change the admin password from the panel settings after your first login.

Key environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `ADMIN_USERNAME` | `admin` | Admin username (min 5 chars) |
| `ADMIN_PASSWORD` | `${{secret(16)}}` | Admin password — see Variables tab |
| `ADMIN_EMAIL` | `admin@example.com` | Placeholder email (no SMTP configured) |
| `PUFFER_PANEL_REGISTRATIONENABLED` | `false` | Public self-registration toggle |

Railway-injected (no action needed): `PORT` (panel web listen port), `RAILWAY_PUBLIC_DOMAIN` (used as the panel's master URL).

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 8080 | TCP | Panel web UI (Railway `PORT`) |
| 5657 | TCP | SFTP daemon — attach a Railway TCP proxy for external file access |
| Game ports (e.g. 2456, 7777, 26900) | UDP | Not exposed by Railway natively — set `PLAYIT_SECRET` (see above) to expose them via playit.gg |

## Supported Game Templates

| Template family | Status on this template | Notes |
|---|---|---|
| Minecraft (Java/Bedrock/FTB/CurseForge/Velocity/Waterfall/Bungee) | ✅ Works | TCP 25565 native via Railway TCP proxy |
| Discord bots (JDA, discord.js, discord.py) | ✅ Works | Java 8/21, Node 20/22/24, pip preinstalled |
| 7 Days to Die, ARK, Satisfactory, Squad | ✅ Installs + boots | Steam SDK wired automatically; join via playit.gg (UDP) |
| Source games (CS:GO/CS:S/TF2/GMod/CS 1.6, Rust, Unturned) | ✅ Installs + boots | 32- & 64-bit Steam SDK linked; join via playit.gg (UDP) |
| Valheim, Don't Starve Together, Eco, Factorio, Terraria (all), Project Zomboid, Vintage Story, Starbound, tModLoader, TShock, PocketMine, TeamSpeak | ✅ Installs + boots | `libcurl-gnutls` shim + mono preinstalled; join via playit.gg (UDP) |
| ARMA 3, Starbound (steam login) | ⚠️ Needs real Steam account | Template asks for Steam credentials at install |

## Why Deploy

- **One-click deploy**: panel + daemon in a single service, zero manual setup
- **Auto-provisioned admin**: credentials generated and printed to Variables on boot
- **Persistent storage**: database, server files, and logs survive redeploys
- **Lightweight**: Go binary + embedded SQLite — no external database service
- **Open source**: Apache 2.0, community-driven Pterodactyl alternative

## Common Use Cases

- Host game servers (Minecraft, Valheim, Terraria, etc.) for friends
- Self-host a lightweight Pterodactyl/Pelican alternative
- Manage per-user access to community game servers
- Provide game server hosting behind a clean web panel

## Dependencies for PufferPanel

This template is fully self-contained — a single service with an embedded SQLite database on a persistent volume.

### Deployment Dependencies

- **None** — SQLite runs inside the container at `/var/lib/pufferpanel/database.db`; no companion services required.

## License

PufferPanel is licensed under the Apache 2.0 License.