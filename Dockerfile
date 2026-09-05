FROM pufferpanel/pufferpanel:3.0.9

# The tty (host) environment hardcodes bash as the server shell
# (servers/tty/tty.go: const Shell = "bash") — the Alpine base only ships
# busybox sh, so game servers would fail with "exec: bash: not found".
# gcompat + libstdc++ + libgcc: PufferPanel downloads glibc-linked binaries at
# runtime (DepotDownloader for SteamCS = .NET self-contained ELF, interpreter
# /lib64/ld-linux-x86-64.so.2) — without these it dies with "cannot execute:
# required file not found". Verified: DepotDownloader 3.4.0 connects to Steam
# with exactly this set.
RUN apk add --no-cache bash gcompat libstdc++ libgcc

# Minecraft/Node game templates auto-download java${version}/node${version} via
# javadl/nodejsdl — but those adoptium/nodejs.org linux-x64 builds are glibc
# linked and FAIL on musl even under gcompat (JNI libjimage won't load).
# javadl/nodejsdl exec.LookPath("java21"/"node20") FIRST and skip the download
# when found — so ship musl-native runtimes and expose them under the exact
# versioned names the templates request.
RUN apk add --no-cache \
      openjdk8-jre-base openjdk17-jre-headless openjdk21-jre-headless \
      openjdk25-jre-headless nodejs npm && \
    ln -sf /usr/lib/jvm/java-8-openjdk/jre/bin/java /usr/local/bin/java8 && \
    ln -sf /usr/lib/jvm/java-17-openjdk/bin/java /usr/local/bin/java17 && \
    ln -sf /usr/lib/jvm/java-21-openjdk/bin/java /usr/local/bin/java21 && \
    ln -sf /usr/lib/jvm/java-25-openjdk/bin/java /usr/local/bin/java25 && \
    ln -sf /usr/bin/java /usr/local/bin/java && \
    ln -sf /usr/bin/node /usr/local/bin/node24 && \
    ln -sf /usr/bin/node /usr/local/bin/node22 && \
    ln -sf /usr/bin/node /usr/local/bin/node20

# Upstream v3.0.9 execs `bash -c ${PUFFERPANEL_SERVER_COMMAND}` unquoted
# (servers/tty/tty.go:360), so bash word-splits the expansion and any
# multi-word server command breaks. Install a PATH shim that re-quotes
# the payload; /bin/bash moves to /bin/bash.real.
COPY bash-shim /usr/local/bin/bash
RUN chmod +x /usr/local/bin/bash && mv /bin/bash /bin/bash.real && \
    ln -sf /usr/local/bin/bash /bin/bash

# Persist panel config (session key, settings) on the data volume so
# user sessions survive redeploys instead of rotating every deploy
# (entrypoint seeds /var/lib/pufferpanel/config.json from the image default)
ENV PUFFER_CONFIG=/var/lib/pufferpanel/config.json

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# 8080 = panel web UI (Railway PORT), 5657 = SFTP daemon (optional TCP proxy)
EXPOSE 8080 5657

# Upstream image runs as root; volume is root-owned on Railway so keep root
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]