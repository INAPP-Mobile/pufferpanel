#!/bin/sh
set -e

# Railway wrapper for the upstream PufferPanel image.
# Upstream entrypoint.sh does: `pufferpanel db upgrade` then `exec pufferpanel run`.
# This wrapper handles first-boot admin bootstrap + Railway-specific env fixes.

DB="/var/lib/pufferpanel/database.db"
MARKER="/var/lib/pufferpanel/.admin-bootstrapped"
PUFFER_CONFIG_TARGET="/var/lib/pufferpanel/config.json"

# --- Persist panel config on the volume -----------------------------------------
# Upstream ships /etc/pufferpanel/config.json (SQLite path, log folder, daemon
# root). Copy it to the volume so the auto-generated session key (written to
# this file by `panel.sessionKey.Set(..., save=true)`) survives redeploys
# instead of rotating and logging every user out.
export PUFFER_CONFIG="${PUFFER_CONFIG_TARGET}"
if [ ! -f "$PUFFER_CONFIG_TARGET" ] && [ -f /etc/pufferpanel/config.json ]; then
  echo "[pufferpanel-railway] Seeding panel config on persistent volume"
  cp /etc/pufferpanel/config.json "$PUFFER_CONFIG_TARGET"
fi

# --- Railway env fixes ------------------------------------------------------------
# 1. disableUnshare=true: Railway lacks CAP_SYS_ADMIN, so upstream's
#    unshare(CLONE_NEWUSER|...) sandbox fails with EPERM at server start.
#    Game servers therefore run as plain host processes under the panel.
export PUFFER_SECURITY_DISABLEUNSHARE=true

# 2. Docker root MUST be non-empty: with PUFFER_PLATFORM=docker (upstream ENV)
#    and an empty docker root, the daemon probes /var/run/docker.sock on boot,
#    fails (no socket on Railway), and the whole panel exits — restart loop.
#    A non-empty PUFFER_DOCKER_ROOT short-circuits that probe.
export PUFFER_DOCKER_ROOT="/var/lib/pufferpanel/docker"

# 3. disallowHost must be FALSE: upstream image sets it true, which strips
#    host/tty/standard from the environment list. With Docker unavailable
#    that would leave ZERO selectable environments for new servers. Keep
#    host environments offered; disableUnshare makes them actually runnable.
export PUFFER_DOCKER_DISALLOWHOST=false

# 4. Web host: bind 0.0.0.0 on Railway's injected PORT (upstream default 8080).
export PUFFER_WEB_HOST="0.0.0.0:${PORT:-8080}"

# 5. Master URL: what the panel reports as the local node address (shown in
#    UI, used for SFTP connection info). Point at the public domain.
export PUFFER_PANEL_SETTINGS_MASTERURL="${RAILWAY_PUBLIC_DOMAIN:-localhost}:${PORT:-8080}"

# --- First-boot admin bootstrap ---------------------------------------------------
# `pufferpanel user add` needs the DB schema, so run db upgrade first (it is
# idempotent; upstream entrypoint runs it again). Marker file on the volume
# prevents repeat attempts after success. Validation is done here (not by
# letting the binary fail) so a misconfigured password cannot restart-loop
# the container.
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

if [ ! -f "$MARKER" ] && [ -n "$ADMIN_PASSWORD" ]; then
  echo "[pufferpanel-railway] Running db upgrade"
  /pufferpanel/bin/pufferpanel db upgrade || echo "[pufferpanel-railway] db upgrade failed (upstream will retry)"

  ok=1
  if [ "${#ADMIN_USERNAME}" -lt 5 ]; then
    echo "[pufferpanel-railway] WARNING: ADMIN_USERNAME too short (min 5 chars) — skipping admin creation"
    ok=0
  fi
  if [ "${#ADMIN_PASSWORD}" -lt 8 ]; then
    echo "[pufferpanel-railway] WARNING: ADMIN_PASSWORD too short (min 8 chars) — skipping admin creation"
    ok=0
  fi
  case "$ADMIN_EMAIL" in
    *@*.*) : ;;
    *) echo "[pufferpanel-railway] WARNING: ADMIN_EMAIL invalid — skipping admin creation"; ok=0 ;;
  esac

  if [ "$ok" -eq 1 ]; then
    echo "[pufferpanel-railway] Creating admin user '$ADMIN_USERNAME'"
    if /pufferpanel/bin/pufferpanel user add \
         --name "$ADMIN_USERNAME" \
         --email "$ADMIN_EMAIL" \
         --admin \
         --password "$ADMIN_PASSWORD"; then
      echo "[pufferpanel-railway] Admin user created"
    else
      echo "[pufferpanel-railway] Admin creation failed (may already exist) — continuing"
    fi
    touch "$MARKER"
  fi
fi

echo "[pufferpanel-railway] Handing off to upstream entrypoint"
exec /pufferpanel/bin/entrypoint.sh