# glibc base (Debian): game servers and everything PufferPanel downloads at
# runtime are glibc-linked (Unity/7DTD relocates UnityPlayer.so against glibc
# symbols, DepotDownloader is a .NET glibc ELF, javadl pulls Adoptium glibc
# JREs). The upstream Alpine image breaks all three (musl); Debian runs them
# natively. Built from the official .deb (no Docker Hub Debian tag exists).
FROM debian:trixie-slim

ARG PP_VERSION=3.0.9
ARG PP_DEB_URL=https://github.com/PufferPanel/PufferPanel/releases/download/v${PP_VERSION}/pufferpanel_${PP_VERSION}_amd64.deb

ADD ${PP_DEB_URL} /tmp/pufferpanel.deb
# deb layout: /usr/sbin/pufferpanel (static binary), /etc/pufferpanel/config.json
# (defaults already point SQLite + daemon root at /var/lib/pufferpanel),
# /var/www/pufferpanel (embedded frontend path). No deb dependencies.
RUN dpkg -i /tmp/pufferpanel.deb && rm /tmp/pufferpanel.deb

# The tty (host) environment hardcodes bash as the server shell
# (servers/tty/tty.go: const Shell = "bash") — present on Debian.
# steamcmd/srcds games want 32-bit runtime libs (lib32gcc-s1); cheap insurance.
RUN apt-get update && apt-get install -y --no-install-recommends \
      bash binutils ca-certificates curl wget lib32gcc-s1 \
      openjdk-21-jre-headless nodejs npm && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf $(ls /usr/lib/jvm/java-21-openjdk*/bin/java | head -1) /usr/local/bin/java21 && \
    ln -sf /usr/bin/node /usr/local/bin/node20 && \
    ln -sf /usr/bin/node /usr/local/bin/node22 && \
    ln -sf /usr/bin/node /usr/local/bin/node24
# javaversion 8/25: javadl exec.LookPath("java8"/"java25") misses locally and
# downloads Adoptium glibc JREs — which now WORK natively on Debian, so no
# musl-JRE workaround needed for uncovered versions.

# Upstream v3.0.9 execs `bash -c ${PUFFERPANEL_SERVER_COMMAND}` unquoted
# (servers/tty/tty.go:360), so bash word-splits the expansion and any
# multi-word server command breaks. Install a PATH shim that re-quotes
# the payload; /bin/bash moves to /bin/bash.real.
COPY bash-shim /usr/local/bin/bash
RUN chmod +x /usr/local/bin/bash && mv /bin/bash /bin/bash.real && \
    ln -sf /usr/local/bin/bash /bin/bash

# Persist panel config (session key, settings) on the data volume so
# user sessions survive redeploys instead of rotating every deploy
# (entrypoint seeds /var/lib/pufferpanel/config.json from the deb default)
ENV PUFFER_CONFIG=/var/lib/pufferpanel/config.json

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# 8080 = panel web UI (Railway PORT), 5657 = SFTP daemon (optional TCP proxy)
EXPOSE 8080 5657

# Run as root: Railway volumes are root-owned, and game servers run as
# host processes under the panel (disableUnshare).
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]