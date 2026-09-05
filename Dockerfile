FROM pufferpanel/pufferpanel:3.0.9

# The tty (host) environment hardcodes bash as the server shell
# (servers/tty/tty.go: const Shell = "bash") — the Alpine base only ships
# busybox sh, so game servers would fail with "exec: bash: not found"
RUN apk add --no-cache bash

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